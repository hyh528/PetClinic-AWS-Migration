# 07-application 레이어 🚀

## 목차
- [개요](#개요)
- [전체 아키텍처](#전체-아키텍처)
- [ECS 서비스 구성](#ecs-서비스-구성)
- [ALB 라우팅 구조](#alb-라우팅-구조)
- [네트워크 흐름 상세](#네트워크-흐름-상세)
- [CloudWatch 모니터링](#cloudwatch-모니터링)
- [코드 구조](#코드-구조)
- [배포 방법](#배포-방법)
- [문제 해결](#문제-해결)

---

## 개요

**07-application 레이어**는 Spring PetClinic **마이크로서비스 4개를 ECS Fargate에 배포**합니다.
모든 레이어가 모이는 **최종 레이어**입니다.

### 이 레이어가 하는 일
- ✅ Application Load Balancer (ALB) 생성
- ✅ ECS Fargate 서비스 4개 배포 (customers, vets, visits, admin)
- ✅ Cloud Map 서비스 디스커버리 연동
- ✅ Parameter Store 설정 자동 로드
- ✅ CloudWatch 모니터링 및 알람 설정
- ✅ GitHub Actions OIDC 배포 권한 설정

### 의존하는 모든 레이어
```
01-network    → VPC, Subnets
02-security   → Security Groups, IAM Roles
03-database   → Aurora MySQL
04-parameter-store → 애플리케이션 설정
05-cloud-map  → 서비스 디스커버리
    ↓
07-application (이 레이어) 🚀
```

---

## 전체 아키텍처

### 배포되는 서비스

| 서비스 | 포트 | CPU | 메모리 | DB 연결 | 용도 |
|--------|------|-----|--------|---------|------|
| **customers-service** | 8080 | 256 | 512 MB | ✅ | 고객 관리 |
| **vets-service** | 8080 | 256 | 512 MB | ✅ | 수의사 관리 |
| **visits-service** | 8080 | 256 | 512 MB | ✅ | 진료 기록 |
| **admin-server** | 9090 | 256 | 512 MB | ❌ | Spring Boot Admin |

---

### 네트워크 다이어그램

```
┌─────────────────────────────────────────────────────────────────┐
│                         Internet (인터넷)                         │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                      WAF (보안)
                           │
                           ↓
        ┌──────────────────────────────────────┐
        │   Application Load Balancer (ALB)   │
        │   - Public Subnet 배치               │
        │   - HTTP/HTTPS 리스너               │
        └───────┬──────────────────────────────┘
                │
        Path-Based Routing
                │
     ┌──────────┼──────────┬──────────┐
     │          │          │          │
     ↓          ↓          ↓          ↓
┌─────────┐┌─────────┐┌─────────┐┌─────────┐
│customers││  vets   ││ visits  ││  admin  │
│ :8080   ││ :8080   ││ :8080   ││ :9090   │
└────┬────┘└────┬────┘└────┬────┘└────┬────┘
     │          │          │          │
     └──────────┴──────────┴──────────┘
                │
            Cloud Map
     (서비스 간 통신 DNS)
                │
     ┌──────────┴──────────┐
     │                     │
     ↓                     ↓
┌─────────────┐    ┌──────────────┐
│ Aurora MySQL│    │  Parameter   │
│  (Writer)   │    │    Store     │
└─────────────┘    └──────────────┘
```

---

## ECS 서비스 구성

### 1. 서비스 정의 (locals.tf)

```hcl
services = {
  customers = {
    name        = "customers-service"
    port        = 8080
    health_path = "/api/customers/actuator/health"
    cpu         = 256
    memory      = 512
  }
  vets = {
    name        = "vets-service"
    port        = 8080
    health_path = "/api/vets/actuator/health"
    cpu         = 256
    memory      = 512
  }
  visits = {
    name        = "visits-service"
    port        = 8080
    health_path = "/api/visits/actuator/health"
    cpu         = 256
    memory      = 512
  }
  admin = {
    name        = "admin-server"
    port        = 9090
    health_path = "/admin/actuator/health"
    cpu         = 256
    memory      = 512
  }
}
```

---

### 2. 공통 환경 변수

모든 서비스(admin 제외)에 공통 적용:

```hcl
# locals.tf
common_environment = [
  {
    name  = "SPRING_PROFILES_ACTIVE"
    value = "mysql,aws"
  },
  {
    name  = "AWS_REGION"
    value = "us-west-2"
  },
  {
    name  = "AWS_ECR_DEBUG"
    value = "true"
  }
]

common_secrets = [
  {
    name      = "SPRING_DATASOURCE_URL"
    valueFrom = "/petclinic/dev/db/url"  # Parameter Store
  },
  {
    name      = "SPRING_DATASOURCE_USERNAME"
    valueFrom = "/petclinic/dev/db/username"  # Parameter Store
  },
  {
    name      = "SPRING_DATASOURCE_PASSWORD"
    valueFrom = "arn:aws:secretsmanager:...:password::"  # Secrets Manager
  }
]
```

**주의**: Admin 서버는 DB 연결이 필요 없으므로 `admin_secrets = []`

---

### 3. Admin 서버 특수 설정

```hcl
admin_environment = [
  {
    name  = "SPRING_PROFILES_ACTIVE"
    value = "aws"  # mysql 프로파일 제외
  },
  {
    name  = "AWS_REGION"
    value = "us-west-2"
  },
  {
    name  = "ALB_DNS_NAME"
    value = module.alb.alb_dns_name  # Admin이 다른 서비스 접근용
  }
]

admin_secrets = []  # DB 연결 불필요
```

---

### 4. Cloud Map 서비스 디스커버리

```hcl
# ECS Service에 Cloud Map 연동
service_registries {
  registry_arn = local.cloudmap_service_arns["customers"]  # customers.petclinic.local
}
```

**동작 원리**:
```
1. ECS Task 시작
   ↓
2. ECS가 Task의 Private IP 조회 (예: 10.0.10.45)
   ↓
3. Cloud Map에 자동 등록
   customers.petclinic.local → 10.0.10.45
   ↓
4. 다른 서비스가 DNS 조회 시 해당 IP 반환
```

---

## ALB 라우팅 구조

### 1. ALB 리스너 규칙

```
HTTP :80 → HTTPS :443 리다이렉트

HTTPS :443
    │
    ├─ Path: /api/customers/*  → customers-service :8080
    ├─ Path: /api/vets/*       → vets-service :8080
    ├─ Path: /api/visits/*     → visits-service :8080
    └─ Path: /admin/*          → admin-server :9090
```

### 2. 라우팅 예시

```
사용자 요청:
https://petclinic-alb.us-west-2.elb.amazonaws.com/api/customers

ALB 처리:
1. HTTPS :443 리스너 매칭
2. Path "/api/customers/*" 규칙 매칭
3. customers-service 타겟 그룹으로 전달
4. ECS Task 10.0.10.45:8080으로 프록시
5. Spring Boot 애플리케이션 응답
```

---

### 3. 헬스체크 설정

| 서비스 | 헬스체크 경로 | 간격 | Timeout | 정상 임계값 | 비정상 임계값 |
|--------|--------------|------|---------|-----------|-------------|
| customers | `/api/customers/actuator/health` | 30초 | 5초 | 2회 | 2회 |
| vets | `/api/vets/actuator/health` | 30초 | 5초 | 2회 | 2회 |
| visits | `/api/visits/actuator/health` | 30초 | 5초 | 2회 | 2회 |
| admin | `/admin/actuator/health` | 30초 | 5초 | 2회 | 2회 |

**헬스체크 실패 시**:
```
1. ALB가 2번 연속 실패 감지
   ↓
2. 해당 Task를 타겟에서 제외
   ↓
3. 트래픽이 정상 Task로만 전달
   ↓
4. ECS가 새 Task 시작 (desired_count 유지)
```

---

## 네트워크 흐름 상세

### 시나리오 1: 외부 사용자 요청

```
1. 사용자 브라우저
   https://petclinic-alb.amazonaws.com/api/customers
   ↓
2. Route 53 (DNS 해석)
   ALB Public IP 반환
   ↓
3. WAF (Web Application Firewall)
   SQL Injection, XSS 차단
   ↓
4. ALB (Public Subnet)
   Security Group: 0.0.0.0/0 :443 허용
   Path 기반 라우팅
   ↓
5. Target Group (customers-service)
   Security Group: ALB SG :8080 허용
   ↓
6. ECS Task (Private App Subnet)
   Private IP: 10.0.10.45:8080
   ↓
7. Spring Boot 애플리케이션
   Parameter Store에서 DB 설정 로드
   ↓
8. Aurora MySQL (Private DB Subnet)
   Security Group: ECS SG :3306 허용
   ↓
9. 응답 역순 전달
```

---

### 시나리오 2: 서비스 간 통신 (Cloud Map)

```
1. Customers Service가 Vets Service 호출 필요
   예: 고객의 담당 수의사 정보 조회
   ↓
2. DNS 조회
   nslookup vets.petclinic.local
   ↓
3. Cloud Map 응답
   10.0.10.67 (Vets Service Task IP)
   ↓
4. HTTP 요청
   GET http://vets.petclinic.local:8080/api/vets/1
   ↓
5. Security Group 확인
   ECS SG Self 규칙: 8080 허용
   ↓
6. Vets Service 응답
   JSON 데이터 반환
```

---

### 시나리오 3: Admin 서버가 서비스 모니터링

```
1. Admin 서버 (Spring Boot Admin)
   서비스 헬스 확인 필요
   ↓
2. ALB DNS를 통해 접근
   GET http://petclinic-alb.amazonaws.com/api/customers/actuator/health
   ↓
3. ALB가 customers-service로 프록시
   ↓
4. Actuator Endpoint 응답
   {
     "status": "UP",
     "components": {
       "db": { "status": "UP" },
       "diskSpace": { "status": "UP" }
     }
   }
   ↓
5. Admin 대시보드에 표시
```

**왜 ALB를 경유?**
- Admin은 DB 연결이 없어서 Cloud Map을 통한 직접 연결 불가
- ALB Public Endpoint를 통해 접근 (NAT Gateway 경유)

---

## CloudWatch 모니터링

### 1. 대시보드 위젯 (6개)

```hcl
# monitoring.tf
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "petclinic-dev-dashboard"
  
  dashboard_body = jsonencode({
    widgets = [
      # Widget 1: ECS CPU 사용률
      # Widget 2: ECS 메모리 사용률
      # Widget 3: ALB 요청 수
      # Widget 4: ALB HTTP 4XX/5XX
      # Widget 5: Aurora DB 연결 수
      # Widget 6: Lambda GenAI 실행 시간
    ]
  })
}
```

**대시보드 URL**:
```
https://console.aws.amazon.com/cloudwatch/home?region=us-west-2#dashboards:name=petclinic-dev-dashboard
```

---

### 2. CloudWatch 알람 (4개)

| 알람 이름 | 메트릭 | 임계값 | 동작 |
|----------|--------|-------|------|
| **ECS High CPU** | CPUUtilization | > 80% | SNS 알림 |
| **ECS High Memory** | MemoryUtilization | > 80% | SNS 알림 |
| **ALB 5XX Errors** | HTTPCode_Target_5XX_Count | > 10 | SNS 알림 |
| **Aurora DB Connections** | DatabaseConnections | > 90 | SNS 알림 |

**알람 트리거 시**:
```
1. CloudWatch 알람 트리거
   ↓
2. SNS Topic 발행
   ↓
3. 이메일/Slack 알림
   "⚠️ ECS CPU 사용률 85% 초과!"
   ↓
4. 운영자 대응
   - Auto Scaling 확인
   - 로그 조회
   - 필요 시 Task 수 증가
```

---

### 3. Container Insights

```hcl
# ECS Cluster에 활성화
resource "aws_ecs_cluster" "this" {
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}
```

**제공 메트릭**:
- Task 레벨 CPU/메모리
- 네트워크 송수신량
- 디스크 I/O

---

## 코드 구조

### 파일 구성

```
07-application/
├── main.tf                  # ECS 서비스, ALB, Target Groups
├── monitoring.tf            # CloudWatch 대시보드 및 알람
├── github-actions.tf        # GitHub Actions OIDC 배포 권한
├── locals.tf                # 서비스 정의, 환경 변수
├── data.tf                  # 다른 레이어 데이터 조회
├── variables.tf             # 변수 정의
├── outputs.tf               # 출력값
├── backend.tf               # Terraform 상태 저장
├── backend.config           # 백엔드 키 설정
├── terraform.tfvars         # 실제 값 입력
└── README.md                # 이 문서
```

---

### main.tf 주요 구조

```hcl
# 1. ALB 모듈
module "alb" {
  source = "../../modules/alb"
  
  name_prefix        = "petclinic"
  vpc_id             = local.vpc_id
  public_subnet_ids  = local.public_subnet_ids
  enable_waf         = true
}

# 2. ECS 서비스 보안 그룹 규칙
resource "aws_security_group_rule" "alb_to_ecs" {
  type                     = "ingress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  security_group_id        = local.ecs_security_group_id
  source_security_group_id = module.alb.alb_security_group_id
}

resource "aws_security_group_rule" "alb_to_ecs_admin" {
  type                     = "ingress"
  from_port                = 9090
  to_port                  = 9090
  protocol                 = "tcp"
  security_group_id        = local.ecs_security_group_id
  source_security_group_id = module.alb.alb_security_group_id
}

# 3. ECS 서비스 간 통신 규칙
resource "aws_security_group_rule" "ecs_inter_service_8080" {
  type              = "ingress"
  from_port         = 8080
  to_port           = 8080
  protocol          = "tcp"
  security_group_id = local.ecs_security_group_id
  self              = true  # 같은 보안 그룹 내 통신 허용
}

# 4. Aurora 접근 허용
resource "aws_security_group_rule" "aurora_allow_ecs" {
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  security_group_id        = local.aurora_security_group_id
  source_security_group_id = local.ecs_security_group_id
}

# 5. ECS Task Definition (반복)
resource "aws_ecs_task_definition" "services" {
  for_each = local.services
  
  family = "${var.name_prefix}-${each.key}"
  
  container_definitions = jsonencode([{
    name  = each.value.name
    image = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${each.value.name}:latest"
    
    portMappings = [{
      containerPort = each.value.port
      protocol      = "tcp"
    }]
    
    environment = each.key == "admin" ? local.admin_environment : local.common_environment
    secrets     = each.key == "admin" ? local.admin_secrets : local.common_secrets
    
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/${var.name_prefix}-${each.key}"
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])
  
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = each.value.cpu
  memory                   = each.value.memory
}

# 6. ECS Service (반복)
resource "aws_ecs_service" "services" {
  for_each = local.services
  
  name            = each.value.name
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.services[each.key].arn
  desired_count   = 1
  launch_type     = "FARGATE"
  
  network_configuration {
    subnets          = local.private_app_subnet_ids
    security_groups  = [local.ecs_security_group_id]
    assign_public_ip = false
  }
  
  load_balancer {
    target_group_arn = aws_lb_target_group.services[each.key].arn
    container_name   = each.value.name
    container_port   = each.value.port
  }
  
  service_registries {
    registry_arn = local.cloudmap_service_arns[each.key]
  }
}

# 7. Target Group (반복)
resource "aws_lb_target_group" "services" {
  for_each = local.services
  
  name        = "${var.name_prefix}-${each.key}-tg"
  port        = each.value.port
  protocol    = "HTTP"
  vpc_id      = local.vpc_id
  target_type = "ip"
  
  health_check {
    enabled             = true
    path                = each.value.health_path
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200"
  }
}

# 8. ALB Listener Rule (반복)
resource "aws_lb_listener_rule" "services" {
  for_each = local.services
  
  listener_arn = module.alb.https_listener_arn
  
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.services[each.key].arn
  }
  
  condition {
    path_pattern {
      values = ["/api/${each.key}/*"]
    }
  }
}
```

---

## 배포 방법

### 사전 요구사항

모든 의존 레이어 배포 완료:
```bash
# 1. Network
terraform output -state=../01-network/terraform.tfstate vpc_id

# 2. Security
terraform output -state=../02-security/terraform.tfstate ecs_security_group_id

# 3. Database
terraform output -state=../03-database/terraform.tfstate cluster_endpoint

# 4. Parameter Store
terraform output -state=../04-parameter-store/terraform.tfstate parameter_count

# 5. Cloud Map
terraform output -state=../05-cloud-map/terraform.tfstate namespace_name
```

---

### 배포 순서

#### 1단계: 작업 디렉토리 이동
```bash
cd terraform/layers/07-application
```

#### 2단계: 변수 파일 확인
```bash
cat terraform.tfvars
```

예시:
```hcl
name_prefix = "petclinic"
environment = "dev"
aws_region  = "us-west-2"
aws_profile = "default"

# ECS 설정
ecs_cluster_name = "petclinic-dev-cluster"

# 백엔드
tfstate_bucket_name = "petclinic-tfstate-oregon-dev"

tags = {
  Project     = "petclinic"
  Environment = "dev"
  ManagedBy   = "terraform"
}
```

#### 3단계: Terraform 초기화
```bash
terraform init \
  -backend-config=../../backend.hcl \
  -backend-config=backend.config
```

#### 4단계: 실행 계획 확인
```bash
terraform plan -var-file=terraform.tfvars
```

**확인사항**:
- ALB 1개
- ECS 서비스 4개
- Target Group 4개
- ALB Listener Rule 4개
- CloudWatch Dashboard 1개
- CloudWatch Alarm 4개

#### 5단계: 배포 실행
```bash
terraform apply -var-file=terraform.tfvars
```

**소요 시간**: 약 10-15분
- ALB 생성: 2-3분
- ECS 서비스 시작: 5-10분 (이미지 다운로드 포함)

#### 6단계: ALB DNS 확인
```bash
terraform output alb_dns_name
# petclinic-dev-alb-xxxxxxxxx.us-west-2.elb.amazonaws.com
```

#### 7단계: 헬스체크 확인
```bash
ALB_DNS=$(terraform output -raw alb_dns_name)

curl http://$ALB_DNS/api/customers/actuator/health
curl http://$ALB_DNS/api/vets/actuator/health
curl http://$ALB_DNS/api/visits/actuator/health
curl http://$ALB_DNS/admin/actuator/health
```

---

## 문제 해결

### 문제 1: ECS Task가 시작하지 않음
```
ERROR: CannotPullContainerError: pull image manifest has been retried
```

**원인**: ECR 이미지가 없음

**해결**:
```bash
# ECR 리포지토리 확인
aws ecr describe-repositories --query 'repositories[*].repositoryName'

# Docker 이미지 푸시 (GitHub Actions 또는 수동)
aws ecr get-login-password | docker login --username AWS --password-stdin ${ACCOUNT_ID}.dkr.ecr.us-west-2.amazonaws.com

docker build -t customers-service .
docker tag customers-service:latest ${ACCOUNT_ID}.dkr.ecr.us-west-2.amazonaws.com/customers-service:latest
docker push ${ACCOUNT_ID}.dkr.ecr.us-west-2.amazonaws.com/customers-service:latest
```

---

### 문제 2: ALB 헬스체크 실패
```
Target.FailedHealthChecks: Health checks failed
```

**디버깅**:
```bash
# 1. Target Group 상태 확인
aws elbv2 describe-target-health \
  --target-group-arn arn:aws:elasticloadbalancing:... \
  --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State,TargetHealth.Reason]'

# 2. ECS Task 로그 확인
aws logs tail /ecs/petclinic-customers --follow

# 3. 직접 헬스체크 (Task IP)
curl http://10.0.10.45:8080/api/customers/actuator/health
```

---

### 문제 3: 서비스 간 통신 실패
```
ERROR: UnknownHostException: vets.petclinic.local
```

**확인**:
```bash
# 1. Cloud Map 등록 확인
aws servicediscovery list-instances \
  --service-id srv-xxxxxxxxx

# 2. ECS Task에서 DNS 조회
aws ecs execute-command \
  --cluster petclinic-dev-cluster \
  --task task-id \
  --container customers-service \
  --interactive \
  --command "/bin/sh"

# nslookup vets.petclinic.local
```

---

### 디버깅 명령어

```bash
# ECS 서비스 상태
aws ecs describe-services \
  --cluster petclinic-dev-cluster \
  --services customers-service

# ECS Task 목록
aws ecs list-tasks \
  --cluster petclinic-dev-cluster \
  --service-name customers-service

# ALB Target Health
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw customers_target_group_arn)

# CloudWatch Logs
aws logs tail /ecs/petclinic-customers --since 30m

# CloudWatch 메트릭
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ServiceName,Value=customers-service \
  --start-time 2025-11-09T00:00:00Z \
  --end-time 2025-11-09T23:59:59Z \
  --period 3600 \
  --statistics Average
```

---

## 비용 예상

| 구성 요소 | 사양 | 월 비용 (USD) |
|----------|------|---------------|
| ALB | 1개 | $16 |
| ECS Fargate (customers) | 256 CPU, 512 MB | $12 |
| ECS Fargate (vets) | 256 CPU, 512 MB | $12 |
| ECS Fargate (visits) | 256 CPU, 512 MB | $12 |
| ECS Fargate (admin) | 256 CPU, 512 MB | $12 |
| CloudWatch Logs | 5GB/월 | $2.50 |
| CloudWatch Alarms | 4개 | $2 |
| CloudWatch Dashboard | 1개 | $3 |
| **합계** | - | **$71.50** |

**전체 인프라 비용** (모든 레이어):
- 01-network: $85
- 03-database: $150
- 07-application: $71.50
- **합계**: **$306.50/월**

---

## 요약

### 핵심 개념 정리
- ✅ **ECS Fargate**: 서버리스 컨테이너 실행
- ✅ **ALB**: Path 기반 라우팅
- ✅ **Cloud Map**: DNS 기반 서비스 디스커버리
- ✅ **Parameter Store**: 설정 중앙 관리
- ✅ **CloudWatch**: 모니터링 및 알람

### 배포되는 리소스
- ALB: 1개
- ECS 서비스: 4개 (customers, vets, visits, admin)
- Target Group: 4개
- CloudWatch Dashboard: 1개
- CloudWatch Alarm: 4개

### 네트워크 흐름
```
Internet → WAF → ALB → ECS (Private Subnet) → Aurora (Private DB Subnet)
                         ↕
                    Cloud Map (서비스 간 통신)
```

---

**작성일**: 2025-11-09  
**작성자**: DevOps Team  
**버전**: 1.0
