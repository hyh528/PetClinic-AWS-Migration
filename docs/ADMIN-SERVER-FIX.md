# Admin 서버 연결 문제 해결

## 문제 상황

Admin UI에서 모든 마이크로서비스(customers, vets, visits)가 **OFFLINE** 상태로 표시됨.

## 원인 분석

### 1. 증상 확인
- 서비스들의 actuator health 엔드포인트는 정상 응답 (HTTP 200, status: UP)
- Admin 서버는 정상 실행 중 (HTTP 200)
- Admin 서버에 등록된 인스턴스 목록은 비어있음 (`[]`)

### 2. 진단 결과
```json
{
  "exception": "java.util.concurrent.TimeoutException",
  "message": "Did not observe any item or terminal signal within 15000ms in 'peek'"
}
```

### 3. 근본 원인: Hairpin NAT 문제
- **Admin 서버는 ECS Fargate private subnet에서 실행**
- **등록된 헬스 URL은 public ALB DNS 주소**
- **네트워크 경로**: ECS 태스크 → NAT Gateway → 인터넷 → ALB → ECS 태스크
- **보안 그룹 이슈**: ECS에서 외부 HTTP (80번 포트)로 나가는 egress 규칙이 ALB 보안 그룹만 참조하고 있어, 공개 인터넷을 통한 ALB 접근이 차단됨

## 해결 방법

### 적용된 해결책: 보안 그룹 Egress 규칙 수정

**파일**: `terraform/layers/07-application/main.tf`

**변경 전**:
```hcl
resource "aws_security_group_rule" "ecs_to_alb_http" {
  type                     = "egress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  security_group_id        = local.ecs_security_group_id
  source_security_group_id = module.alb.alb_security_group_id
  description = "Allow ECS (Admin) to access ALB on port 80 to reach service actuators"
}
```

**변경 후**:
```hcl
resource "aws_security_group_rule" "ecs_to_internet_http" {
  type              = "egress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  security_group_id = local.ecs_security_group_id
  cidr_blocks       = ["0.0.0.0/0"]
  description = "Allow ECS to access internet on port 80 (for Admin to access ALB public DNS)"
}
```

### 왜 이 변경이 필요한가?

1. **공개 DNS 해결**: Admin 서버가 `petclinic-dev-alb-xxxxx.elb.amazonaws.com`에 접근하려면 DNS가 공개 IP로 해석됨
2. **NAT Gateway 경유**: Private subnet의 ECS 태스크는 NAT Gateway를 통해 인터넷으로 나가야 함
3. **보안 그룹 제약**: 기존 규칙은 ALB SG만 참조하여 실제 인터넷 경로로 나가는 트래픽을 차단함

## 배포 절차

### 1. Terraform 변경사항 적용
```bash
cd terraform/layers/07-application
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

### 2. ECS 서비스 재시작 (필요시)
```bash
aws ecs update-service \
  --cluster petclinic-dev-cluster \
  --service petclinic-dev-admin \
  --force-new-deployment
```

### 3. 서비스 재등록
```bash
cd /home/user/webapp
./scripts/register-services-to-admin.sh
```

### 4. 확인 (30초 대기 후)
```bash
curl -s -H "Accept: application/json" \
  http://petclinic-dev-alb-xxxxx.elb.amazonaws.com/admin/instances | \
  jq '.[] | {name: .registration.name, status: .statusInfo.status}'
```

예상 결과:
```json
{
  "name": "customers-service",
  "status": "UP"
}
{
  "name": "vets-service",
  "status": "UP"
}
{
  "name": "visits-service",
  "status": "UP"
}
```

## 🔄 추가 문제 및 해결 (2차 수정 - 2025-11-06)

### 문제: 서비스가 등록되었으나 여전히 DOWN 상태
등록 URL은 올바르지만 **403 Forbidden** 에러 발생:
```json
{
  "error": "Forbidden",
  "status": 403
}
```

### 원인: WAF Rate Limiting
- **BurstRateLimit 규칙**이 `/api/` 경로에 대해 1분간 200개 요청 제한
- Admin 서버가 NAT Gateway의 단일 IP에서 반복적으로 헬스 체크 요청
- `/api/*/actuator/health` 경로가 Rate Limit에 걸림

### 해결책: Actuator 경로 Rate Limiting 제외
**파일**: `terraform/modules/alb/main.tf`

WAF BurstRateLimit 규칙에 actuator 경로 예외 추가:
```hcl
# actuator 경로 제외 (헬스 체크는 Rate Limit 적용 안 함)
statement {
  not_statement {
    statement {
      byte_match_statement {
        search_string = "/actuator/"
        positional_constraint = "CONTAINS"
        # 모든 actuator 하위 경로 제외
      }
    }
  }
}
```

**영향**:
- ✅ Admin 서버의 헬스 체크 요청이 WAF에 의해 차단되지 않음
- ✅ 일반 API 요청은 여전히 Rate Limiting 보호 유지
- ✅ 보안과 모니터링 기능의 균형 유지
- ⚠️ Actuator 엔드포인트는 추가 보안 설정 권장 (Spring Security)

## 장기적인 개선 방안

### Option 1: Cloud Map (Service Discovery) 활용 ⭐ 권장
- **장점**: 
  - 내부 DNS를 통한 직접 서비스 통신
  - Hairpin NAT 문제 완전 해결
  - 낮은 레이턴시
- **구현**: 이미 `05-cloud-map` layer가 존재함
- **변경 필요**:
  - ECS 서비스에 Service Discovery 연결 추가
  - Admin 서버 등록 URL을 `http://customers.petclinic.local:8080` 형식으로 변경

### Option 2: ECS Service Connect 사용
- AWS에서 제공하는 관리형 서비스 메시
- 자동 서비스 디스커버리 및 로드 밸런싱

### Option 3: 현재 구조 유지
- 현재 적용한 보안 그룹 규칙으로 작동
- Admin 서버가 계속 public ALB를 통해 접근
- 추가 레이턴시 발생 가능

## 보안 고려사항

### 현재 적용된 규칙의 보안 영향
- **허용 범위**: ECS 태스크에서 모든 인터넷으로 HTTP(80) egress
- **위험도**: 낮음
  - Private subnet의 태스크는 NAT Gateway를 통해서만 나감
  - Ingress는 여전히 제한됨 (ALB를 통해서만)
  - Admin 서버만 이 경로를 사용
  
### 추가 보안 강화 (선택사항)
- **Network ACL**: NAT Gateway의 outbound를 특정 IP 대역으로 제한
- **VPC Flow Logs**: 네트워크 트래픽 모니터링
- **WAF 규칙**: Admin UI 접근 제어 강화

## 진단 스크립트

문제 재발 시 진단을 위해 스크립트 제공:
```bash
./scripts/diagnose-admin-connectivity.sh
```

## 참고 자료
- [AWS ECS Networking](https://docs.aws.amazon.com/ecs/latest/developerguide/task-networking.html)
- [Spring Boot Admin Documentation](https://codecentric.github.io/spring-boot-admin/current/)
- [AWS Security Group Best Practices](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_SecurityGroups.html)

## 작업 이력
- **2025-11-06**: 초기 문제 진단 및 해결책 적용
- **담당**: GenSpark AI Developer
- **브랜치**: `develop`
