# 02-security 레이어 🔒

## 목차
- [개요](#개요)
- [AWS 보안 기초 개념](#aws-보안-기초-개념)
- [우리가 만드는 보안 구조](#우리가-만드는-보안-구조)
- [보안 그룹 규칙 상세 설명](#보안-그룹-규칙-상세-설명)
- [IAM 역할과 정책](#iam-역할과-정책)
- [코드 구조](#코드-구조)
- [배포 방법](#배포-방법)
- [문제 해결](#문제-해결)

---

## 개요

**02-security 레이어**는 AWS 인프라의 **보안 계층**을 구축합니다.
네트워크(01-network)가 "도로"라면, 보안 레이어는 "교통 신호등과 검문소"에 해당합니다.

### 이 레이어가 하는 일
- ✅ 보안 그룹 (Security Groups) 생성 - 네트워크 방화벽
- ✅ IAM 역할 (IAM Roles) 생성 - 서비스 권한 관리
- ✅ IAM 정책 (IAM Policies) 생성 - 세부 권한 정의
- ✅ 최소 권한 원칙 (Least Privilege) 적용

### 다른 레이어와의 관계
```
01-network (네트워크 기반)
    ↓
02-security (이 레이어) 🔒
    ↓
    ├─→ 03-ecs-cluster (ECS 클러스터)
    ├─→ 04-database (데이터베이스)
    ├─→ 06-lambda-genai (Lambda 함수)
    └─→ 07-application (애플리케이션 서비스)
```

모든 상위 레이어는 이 보안 그룹과 IAM 역할을 사용합니다.

---

## AWS 보안 기초 개념

### 1. 보안 그룹 (Security Group) 🛡️

**쉽게 설명**: 보안 그룹은 EC2, ECS, RDS 등의 **가상 방화벽**입니다.

집에 있는 보안문을 생각하면 됩니다:
- 누가 들어올 수 있는지 (Inbound Rules)
- 어디로 나갈 수 있는지 (Outbound Rules)

#### 보안 그룹의 특징

| 특징 | 설명 | 예시 |
|------|------|------|
| **Stateful** | 들어온 연결의 응답은 자동 허용 | HTTP 요청 허용하면 응답도 자동 허용 |
| **Allow Only** | 허용 규칙만 존재 (거부 규칙 없음) | 명시적으로 허용한 것만 통과 |
| **기본 거부** | 규칙이 없으면 모든 트래픽 차단 | 안전한 기본 설정 |
| **다중 적용** | 1개 리소스에 여러 보안 그룹 적용 가능 | ECS + ALB 보안 그룹 동시 적용 |

#### Inbound vs Outbound

```
Inbound (인바운드):
┌─────────────┐       ┌─────────────┐
│  외부/다른   │  →    │  우리 서비스  │
│   서비스    │       │   (ECS 등)  │
└─────────────┘       └─────────────┘
예: ALB → ECS로 들어오는 HTTP 요청

Outbound (아웃바운드):
┌─────────────┐       ┌─────────────┐
│  우리 서비스  │  →    │  외부/다른   │
│  (ECS 등)   │       │   서비스    │
└─────────────┘       └─────────────┘
예: ECS → RDS로 나가는 PostgreSQL 연결
```

---

### 2. IAM 역할 (IAM Role) 👤

**쉽게 설명**: IAM 역할은 AWS 서비스가 **다른 AWS 서비스를 사용할 권한**입니다.

회사 출입증을 생각하면 됩니다:
- 개발자 출입증: 개발실 출입 가능
- 관리자 출입증: 모든 방 출입 가능
- 손님 출입증: 로비만 출입 가능

#### IAM 역할 vs IAM 사용자

| 구분 | IAM 사용자 | IAM 역할 |
|------|-----------|---------|
| **용도** | 사람이 AWS에 로그인 | 서비스가 다른 서비스 사용 |
| **인증** | ID/Password | 임시 보안 자격 증명 |
| **예시** | 개발자가 CLI 사용 | ECS가 ECR 이미지 다운로드 |

**우리 프로젝트**: ECS 컨테이너가 ECR, CloudWatch, Secrets Manager에 접근하려면 IAM 역할 필요

---

### 3. IAM 정책 (IAM Policy) 📜

**쉽게 설명**: IAM 정책은 **무엇을 할 수 있는지 구체적으로 정의**한 문서입니다.

출입증(역할)에 붙어 있는 "허가된 활동 목록"이라고 생각하면 됩니다.

#### IAM 정책 예시

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchGetImage",
        "ecr:GetDownloadUrlForLayer"
      ],
      "Resource": "*"
    }
  ]
}
```

**해석**: 
- "ECR에서 인증 받고, 이미지 가져오기를 허용합니다"
- ECS 컨테이너가 Docker 이미지를 다운로드하려면 이 정책 필요

---

### 4. 최소 권한 원칙 (Least Privilege Principle) 🎯

**쉽게 설명**: **꼭 필요한 권한만** 부여하는 보안 원칙입니다.

나쁜 예:
```json
{
  "Effect": "Allow",
  "Action": "*",        // 모든 작업 허용 (위험!)
  "Resource": "*"       // 모든 리소스 (위험!)
}
```

좋은 예:
```json
{
  "Effect": "Allow",
  "Action": [
    "secretsmanager:GetSecretValue"  // 비밀 읽기만 허용
  ],
  "Resource": "arn:aws:secretsmanager:us-west-2:123456789012:secret:db-password"
}
```

**우리 프로젝트**: 각 서비스마다 필요한 최소한의 권한만 부여

---

## 우리가 만드는 보안 구조

### 전체 보안 아키텍처

```
┌─────────────────────────────────────────────────────────────────┐
│                         Internet (인터넷)                         │
└────────────────────────┬────────────────────────────────────────┘
                         │
                    [WAF 🛡️] (09-waf 레이어)
                         │
                         ↓
            ┌────────────────────────┐
            │  ALB Security Group    │  ← 80/443 포트만 허용
            │  (alb-sg)              │
            └────────────┬───────────┘
                         │
                         ↓
            ┌────────────────────────┐
            │  ECS Security Group    │  ← ALB에서만 접근 허용
            │  (ecs-sg)              │     8080-8088 포트
            └────────┬───────┬───────┘
                     │       │
         ┌───────────┘       └───────────┐
         ↓                                ↓
┌─────────────────┐            ┌─────────────────┐
│  RDS Security   │            │  VPC Endpoint   │
│  Group          │            │  Security Group │
│  (rds-sg)       │            │  (vpce-sg)      │
│                 │            │                 │
│  PostgreSQL     │            │  ECR, Logs,     │
│  5432 포트      │            │  Secrets 등     │
└─────────────────┘            └─────────────────┘
     ↑                                  ↑
     └──── ECS에서만 접근 허용 ──────────┘
```

---

### 보안 그룹 목록

| 보안 그룹 이름 | 용도 | 주요 규칙 |
|---------------|------|----------|
| **alb-sg** | Application Load Balancer | Inbound: 0.0.0.0/0:80,443<br>Outbound: ECS:8080-8088 |
| **ecs-sg** | ECS Fargate 컨테이너 | Inbound: ALB:8080-8088<br>Outbound: RDS:5432, VPC Endpoints |
| **rds-sg** | Aurora PostgreSQL | Inbound: ECS:5432<br>Outbound: 없음 (DB는 나갈 필요 없음) |
| **vpce-sg** | VPC Endpoints | Inbound: ECS:443<br>Outbound: 없음 |

---

## 보안 그룹 규칙 상세 설명

### 1. ALB Security Group (alb-sg)

**목적**: 외부 인터넷에서 들어오는 HTTP/HTTPS 트래픽을 받아서 ECS로 전달

#### Inbound Rules (들어오는 트래픽)

| 타입 | 프로토콜 | 포트 | 소스 | 설명 |
|------|---------|------|------|------|
| HTTP | TCP | 80 | 0.0.0.0/0 | 전 세계에서 HTTP 접근 허용 |
| HTTPS | TCP | 443 | 0.0.0.0/0 | 전 세계에서 HTTPS 접근 허용 |

```hcl
# HTTP 규칙 예시
ingress {
  from_port   = 80
  to_port     = 80
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]  # 모든 IP 허용
  description = "Allow HTTP from internet"
}
```

#### Outbound Rules (나가는 트래픽)

| 타입 | 프로토콜 | 포트 | 대상 | 설명 |
|------|---------|------|------|------|
| Custom TCP | TCP | 8080-8088 | ecs-sg | ECS 컨테이너로 전달 |

```
사용자 브라우저
    ↓ (HTTP/HTTPS)
[ALB Security Group] ← 여기서 검사
    ↓ (8080-8088)
ECS 컨테이너
```

---

### 2. ECS Security Group (ecs-sg)

**목적**: ECS 컨테이너가 ALB의 요청을 받고, RDS/VPC 엔드포인트에 접근

#### Inbound Rules

| 타입 | 프로토콜 | 포트 | 소스 | 설명 |
|------|---------|------|------|------|
| Custom TCP | TCP | 8080 | alb-sg | api-gateway 서비스 |
| Custom TCP | TCP | 8081 | alb-sg | customers-service |
| Custom TCP | TCP | 8082 | alb-sg | vets-service |
| Custom TCP | TCP | 8083 | alb-sg | visits-service |
| Custom TCP | TCP | 8084 | alb-sg | admin-server |
| Custom TCP | TCP | 8888 | alb-sg | config-server |
| Custom TCP | TCP | 8761 | alb-sg | discovery-server |

```hcl
# ALB에서만 접근 허용
ingress {
  from_port                = 8080
  to_port                  = 8088
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id  # ALB SG만
  description              = "Allow traffic from ALB"
}
```

#### Outbound Rules

| 타입 | 프로토콜 | 포트 | 대상 | 설명 |
|------|---------|------|------|------|
| PostgreSQL | TCP | 5432 | rds-sg | Aurora DB 접근 |
| HTTPS | TCP | 443 | vpce-sg | VPC Endpoints (ECR, Logs 등) |
| All | All | All | 0.0.0.0/0 | 외부 API 호출 (NAT Gateway 경유) |

```
ECS 컨테이너가 할 수 있는 일:
✅ Aurora DB 쿼리 (5432 포트)
✅ ECR에서 이미지 다운로드 (VPC Endpoint)
✅ CloudWatch로 로그 전송 (VPC Endpoint)
✅ Secrets Manager에서 비밀번호 조회 (VPC Endpoint)
✅ 외부 API 호출 (예: 날씨 API)
```

---

### 3. RDS Security Group (rds-sg)

**목적**: Aurora PostgreSQL이 ECS에서만 접근을 받음

#### Inbound Rules

| 타입 | 프로토콜 | 포트 | 소스 | 설명 |
|------|---------|------|------|------|
| PostgreSQL | TCP | 5432 | ecs-sg | ECS 컨테이너만 DB 접근 허용 |

```hcl
ingress {
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ecs.id  # ECS SG만
  description              = "Allow PostgreSQL from ECS"
}
```

#### Outbound Rules

**없음** - 데이터베이스는 외부로 나갈 필요가 없습니다.

**보안 효과**:
```
✅ ECS → RDS (허용)
❌ 인터넷 → RDS (차단)
❌ ALB → RDS (차단)
❌ Lambda → RDS (차단, 필요 시 Lambda SG 추가)
```

---

### 4. VPC Endpoint Security Group (vpce-sg)

**목적**: ECS가 VPC 엔드포인트를 통해 AWS 서비스 사용

#### Inbound Rules

| 타입 | 프로토콜 | 포트 | 소스 | 설명 |
|------|---------|------|------|------|
| HTTPS | TCP | 443 | ecs-sg | ECS에서 AWS 서비스 접근 |

```
ECS → VPC Endpoint → AWS 서비스
         ↑
   [vpce-sg 검사]
   
허용되는 서비스:
- ECR (Docker 이미지)
- CloudWatch Logs (로그)
- Secrets Manager (비밀번호)
- SSM Parameter Store (설정값)
- KMS (암호화 키)
```

---

## IAM 역할과 정책

### 1. ECS Task Execution Role

**목적**: ECS가 컨테이너를 **시작**할 때 필요한 권한

```
ECS 서비스가 하는 일:
1. ECR에서 Docker 이미지 다운로드
2. CloudWatch Logs에 로그 그룹 생성
3. Secrets Manager에서 환경 변수 조회
```

#### 첨부된 정책들

| 정책 이름 | 용도 |
|----------|------|
| **AmazonECSTaskExecutionRolePolicy** | AWS 관리형 - ECR, CloudWatch 기본 권한 |
| **SecretsManagerReadWrite** | Secrets Manager 비밀 읽기 |
| **SSMParameterStoreAccess** | Parameter Store 파라미터 읽기 |

#### 정책 예시 (Secrets Manager)

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ],
      "Resource": "arn:aws:secretsmanager:us-west-2:*:secret:petclinic-*"
    }
  ]
}
```

---

### 2. ECS Task Role

**목적**: ECS 컨테이너가 **실행 중**에 AWS 서비스를 사용할 권한

```
애플리케이션 코드가 하는 일:
1. S3에서 파일 읽기/쓰기
2. DynamoDB 테이블 쿼리
3. SQS 메시지 전송/수신
4. SNS 알림 발송
```

**우리 프로젝트**: 각 서비스(customers, vets 등)마다 Task Role 생성 (07-application 레이어에서)

---

### 3. Lambda Execution Role (06-lambda-genai 레이어)

**목적**: Lambda 함수가 Bedrock AI, RDS Data API 사용

```
Lambda 함수가 하는 일:
1. Bedrock AI 모델 호출 (GenAI 챗봇)
2. RDS Data API로 Aurora 쿼리
3. CloudWatch Logs에 로그 기록
```

---

## 코드 구조

### 파일 구성

```
02-security/
├── main.tf              # 보안 그룹 및 IAM 역할 생성
├── data.tf              # 01-network 레이어 데이터 조회
├── locals.tf            # 로컬 변수 정의
├── variables.tf         # 변수 정의
├── outputs.tf           # 출력값 (다른 레이어에서 사용)
├── backend.tf           # Terraform 상태 저장 설정
├── backend.config       # 백엔드 키 설정
├── terraform.tfvars     # 실제 값 입력
└── README.md            # 이 문서
```

### main.tf 주요 구성

```hcl
# 1. 보안 그룹 모듈
module "security_groups" {
  source = "../../modules/security"
  
  name_prefix            = "petclinic"
  environment            = "dev"
  vpc_id                 = local.vpc_id              # 01-network에서 가져옴
  vpce_security_group_id = local.vpce_security_group_id
  
  # ALB 보안 그룹 (07-application 배포 후 사용)
  alb_security_group_id  = local.alb_sg_id
}

# 2. IAM 역할 모듈
module "iam_roles" {
  source = "../../modules/iam"
  
  project_name               = "petclinic"
  team_members               = ["yeonghyeon", "seokgyeom", "junje", "hwigwon"]
  enable_role_based_policies = false  # Phase 1: 기본 정책만
}
```

### data.tf - 네트워크 레이어 참조

```hcl
# 01-network 레이어의 출력값 가져오기
data "terraform_remote_state" "network" {
  backend = "s3"
  
  config = {
    bucket = "petclinic-tfstate-oregon-dev"
    key    = "network/terraform.tfstate"
    region = "us-west-2"
  }
}

# VPC ID 사용
locals {
  vpc_id                 = data.terraform_remote_state.network.outputs.vpc_id
  vpce_security_group_id = data.terraform_remote_state.network.outputs.vpce_security_group_id
}
```

---

## 배포 방법

### 사전 요구사항

1. **01-network 레이어 배포 완료**
```bash
cd ../01-network
terraform output vpc_id
# 출력이 나와야 함: vpc-xxxxxxxxxxxx
```

2. **AWS CLI 권한 확인**
```bash
aws sts get-caller-identity
# IAM 사용자/역할 정보 확인
```

---

### 배포 순서

#### 1단계: 작업 디렉토리 이동
```bash
cd terraform/layers/02-security
```

#### 2단계: 변수 파일 확인
```bash
cat terraform.tfvars
```

예시:
```hcl
name_prefix  = "petclinic"
environment  = "dev"
aws_region   = "us-west-2"
aws_profile  = "default"

# 보안 설정
enable_vpc_flow_logs    = true
enable_cloudtrail       = true
enable_alb_integration  = false  # ALB 배포 전에는 false

# IAM 사용자 (선택)
team_members = [
  "yeonghyeon",
  "seokgyeom",
  "junje",
  "hwigwon"
]

enable_role_based_policies = false  # Phase 1

# Terraform 백엔드
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
- 보안 그룹 4개 생성 (ALB, ECS, RDS, VPC Endpoint)
- IAM 역할 1개 생성 (ECS Task Execution Role)
- IAM 정책 3개 생성 (Secrets Manager, SSM, CloudWatch)

#### 5단계: 배포 실행
```bash
terraform apply -var-file=terraform.tfvars
```

**소요 시간**: 약 1-2분

#### 6단계: 배포 확인
```bash
# 보안 그룹 ID 확인
terraform output ecs_security_group_id
terraform output aurora_security_group_id
terraform output alb_security_group_id

# IAM 역할 ARN 확인
terraform output ecs_task_execution_role_arn
```

**AWS Console에서 확인**:
1. EC2 대시보드 → "Security Groups"
2. IAM 대시보드 → "Roles" → "petclinic-ecs-task-execution-role"

---

### ALB 배포 후 업데이트 (중요!)

07-application 레이어에서 ALB를 배포한 후, 보안 그룹을 업데이트해야 합니다.

#### 1단계: ALB 보안 그룹 ID 조회
```bash
cd ../07-application
terraform output alb_security_group_id
# sg-xxxxxxxxxxxxxxxxx
```

#### 2단계: 02-security 변수 업데이트
```bash
cd ../../02-security
vim terraform.tfvars
```

```hcl
enable_alb_integration = true  # false → true로 변경
```

#### 3단계: 보안 그룹 업데이트
```bash
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

**변경사항**: ECS 보안 그룹의 Inbound 규칙에 ALB SG 추가

---

## 문제 해결

### 문제 1: VPC ID를 찾을 수 없음
```
Error: vpc_id not found in network remote state
```

**원인**: 01-network 레이어가 배포되지 않음

**해결**:
```bash
cd ../01-network
terraform init -backend-config=../../backend.hcl -backend-config=backend.config
terraform apply -var-file=terraform.tfvars

# 배포 후 다시 시도
cd ../02-security
terraform apply -var-file=terraform.tfvars
```

---

### 문제 2: IAM 역할 생성 실패
```
Error: creating IAM Role: EntityAlreadyExists
```

**원인**: 이미 같은 이름의 IAM 역할이 존재

**해결**:
```bash
# 기존 역할 확인
aws iam get-role --role-name petclinic-ecs-task-execution-role

# 기존 역할 삭제 (주의!)
aws iam delete-role --role-name petclinic-ecs-task-execution-role

# 또는 terraform.tfvars에서 name_prefix 변경
name_prefix = "petclinic-v2"
```

---

### 문제 3: 보안 그룹 규칙이 작동하지 않음
```
ECS 컨테이너가 RDS에 연결할 수 없음
```

**디버깅 단계**:

1. **보안 그룹 확인**
```bash
terraform output ecs_security_group_id
terraform output aurora_security_group_id

aws ec2 describe-security-groups --group-ids sg-xxxxxxxxx
```

2. **Outbound 규칙 확인** (ECS → RDS)
```bash
aws ec2 describe-security-groups \
  --group-ids <ecs-sg-id> \
  --query 'SecurityGroups[0].IpPermissionsEgress'
```

3. **Inbound 규칙 확인** (RDS)
```bash
aws ec2 describe-security-groups \
  --group-ids <rds-sg-id> \
  --query 'SecurityGroups[0].IpPermissions'
```

**해결**: 규칙이 없으면 수동으로 추가
```bash
aws ec2 authorize-security-group-ingress \
  --group-id <rds-sg-id> \
  --protocol tcp \
  --port 5432 \
  --source-group <ecs-sg-id>
```

---

### 문제 4: IAM 정책 권한 부족
```
Error: AccessDenied - not authorized to perform: secretsmanager:GetSecretValue
```

**원인**: ECS Task Execution Role에 정책이 첨부되지 않음

**해결**:
```bash
# 역할에 첨부된 정책 확인
aws iam list-attached-role-policies \
  --role-name petclinic-ecs-task-execution-role

# 정책 ARN 확인
terraform output rds_secret_access_policy_arn

# 정책 수동 첨부 (임시 해결)
aws iam attach-role-policy \
  --role-name petclinic-ecs-task-execution-role \
  --policy-arn <policy-arn>
```

---

### 디버깅 명령어

```bash
# 보안 그룹 규칙 상세 조회
aws ec2 describe-security-groups \
  --group-ids sg-xxxxxxxxx \
  --output table

# IAM 역할 정보 조회
aws iam get-role --role-name petclinic-ecs-task-execution-role

# IAM 정책 문서 조회
aws iam get-policy-version \
  --policy-arn arn:aws:iam::123456789012:policy/petclinic-rds-secret-access \
  --version-id v1

# 보안 그룹 연결된 리소스 확인 (ECS, RDS 등)
aws ec2 describe-instances \
  --filters "Name=instance.group-id,Values=sg-xxxxxxxxx"
```

---

## 보안 베스트 프랙티스

### 1. 최소 권한 원칙
```
❌ 나쁜 예:
egress {
  from_port   = 0
  to_port     = 0
  protocol    = "-1"  # 모든 프로토콜
  cidr_blocks = ["0.0.0.0/0"]  # 모든 IP
}

✅ 좋은 예:
egress {
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.rds.id  # RDS SG만
}
```

---

### 2. 보안 그룹 이름 규칙
```
petclinic-dev-ecs-sg
    ↑      ↑   ↑  ↑
    │      │   │  └─ 타입 (Security Group)
    │      │   └──── 용도 (ECS)
    │      └──────── 환경 (Development)
    └─────────────── 프로젝트명
```

---

### 3. 태그 전략
```hcl
tags = {
  Name        = "petclinic-dev-ecs-sg"
  Environment = "dev"
  ManagedBy   = "terraform"
  Layer       = "02-security"
  Purpose     = "ECS Fargate containers"
}
```

---

### 4. IAM 역할 명명 규칙
```
petclinic-ecs-task-execution-role
    ↑       ↑        ↑        ↑
    │       │        │        └─ 타입 (Role)
    │       │        └────────── 용도 (Task Execution)
    │       └─────────────────── 서비스 (ECS)
    └─────────────────────────── 프로젝트명
```

---

## 비용 예상

| 리소스 | 수량 | 월 비용 (USD) |
|--------|------|---------------|
| 보안 그룹 | 4개 | $0 (무료) |
| IAM 역할 | 1개 | $0 (무료) |
| IAM 정책 | 3개 | $0 (무료) |
| VPC Flow Logs (선택) | 1개 | $5-10 |
| CloudTrail (선택) | 1개 | $2 |
| **합계** | - | **$0-12** |

**보안 리소스는 대부분 무료입니다!**

---

## 다음 단계

보안 레이어 배포가 완료되면:

1. **03-ecs-cluster**: ECS 클러스터 생성
2. **04-database**: Aurora PostgreSQL (rds-sg 사용)
3. **07-application**: ECS 서비스 배포 (ecs-sg, alb-sg 사용)

```bash
cd ../03-ecs-cluster
terraform init -backend-config=../../backend.hcl -backend-config=backend.config
terraform plan -var-file=terraform.tfvars
```

---

## 요약

### 핵심 개념 정리
- ✅ **보안 그룹**: 가상 방화벽, Inbound/Outbound 규칙
- ✅ **IAM 역할**: 서비스가 다른 서비스를 사용할 권한
- ✅ **IAM 정책**: 구체적인 권한 정의 (JSON 문서)
- ✅ **최소 권한 원칙**: 꼭 필요한 권한만 부여

### 생성되는 주요 리소스
- 보안 그룹 4개 (ALB, ECS, RDS, VPC Endpoint)
- IAM 역할 1개 (ECS Task Execution Role)
- IAM 정책 3개 (Secrets Manager, SSM, CloudWatch)

### 보안 규칙 요약
```
Internet → ALB (80,443)
ALB → ECS (8080-8088)
ECS → RDS (5432)
ECS → VPC Endpoints (443)
```

---

**작성일**: 2025-11-09  
**작성자**: DevOps Team  
**버전**: 1.0
