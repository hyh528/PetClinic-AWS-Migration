# 04-parameter-store 레이어 ⚙️

## 목차
- [개요](#개요)
- [AWS Systems Manager Parameter Store 개념](#aws-systems-manager-parameter-store-개념)
- [Spring Cloud Config Server 대체](#spring-cloud-config-server-대체)
- [우리가 저장하는 파라미터](#우리가-저장하는-파라미터)
- [애플리케이션 사용 방법](#애플리케이션-사용-방법)
- [코드 구조](#코드-구조)
- [배포 방법](#배포-방법)
- [문제 해결](#문제-해결)

---

## 개요

**04-parameter-store 레이어**는 Spring PetClinic 애플리케이션의 **설정 값을 중앙에서 관리**합니다.
기존 **Spring Cloud Config Server**를 **AWS Parameter Store**로 대체했습니다.

### 이 레이어가 하는 일
- ✅ 애플리케이션 설정 값을 Parameter Store에 저장
- ✅ 데이터베이스 연결 정보 (JDBC URL, Username) 저장
- ✅ 서비스별 포트 설정 (8080, 9090) 저장
- ✅ Spring Profile 및 로깅 레벨 설정
- ✅ **Config Server 제거** - 더 이상 별도 서버 불필요

### 다른 레이어와의 관계
```
03-database (Aurora 엔드포인트)
    ↓
04-parameter-store (이 레이어) ⚙️
    ↓
07-application (ECS 서비스가 Parameter 조회)
```

---

## AWS Systems Manager Parameter Store 개념

### 1. Parameter Store란? 📦

**쉽게 설명**: AWS가 제공하는 **설정 값 저장소**입니다.

환경변수를 코드에 하드코딩하지 않고, 중앙에서 관리하고 런타임에 불러옵니다.

#### 기존 방식 (application.yml 하드코딩)
```yaml
# ❌ 나쁜 예: 설정이 코드에 고정됨
spring:
  datasource:
    url: jdbc:mysql://prod-db.abc.us-west-2.rds.amazonaws.com:3306/petclinic
    username: petclinic
    password: hardcoded-password  # 보안 위험!
  
server:
  port: 8080
```

**문제점**:
- 환경별 설정 변경 시 코드 수정 및 재배포 필요
- 비밀번호가 Git에 노출
- Dev/Staging/Prod 환경마다 다른 이미지 빌드 필요

#### Parameter Store 방식
```yaml
# ✅ 좋은 예: 런타임에 Parameter Store에서 조회
spring:
  datasource:
    url: ${ssm:/petclinic-seoul/dev/db/url}
    username: ${ssm:/petclinic-seoul/dev/db/username}
    password: ${secretsmanager:petclinic-db-password:password::}

server:
  port: ${ssm:/petclinic-seoul/dev/customers/server.port}
```

**장점**:
- 설정 변경 시 Terraform만 업데이트
- 비밀번호는 Secrets Manager에 암호화 저장
- 모든 환경에서 동일한 Docker 이미지 사용
- 중앙 관리로 일관성 유지

---

### 2. Parameter 타입 🔑

| 타입 | 용도 | 암호화 | 비용 |
|------|------|--------|------|
| **String** | 일반 설정 값 | ❌ 평문 | 무료 |
| **StringList** | 쉼표로 구분된 리스트 | ❌ 평문 | 무료 |
| **SecureString** | 민감한 정보 | ✅ KMS 암호화 | 무료 (KMS 사용료 별도) |

**우리 프로젝트**:
- **String**: JDBC URL, Username, 서버 포트, 로깅 레벨
- **SecureString**: 사용 안 함 (비밀번호는 Secrets Manager 사용)

---

### 3. Parameter 계층 구조 📂

Parameter Store는 **경로 기반**으로 구조화됩니다.

```
/petclinic-seoul/                        # 프로젝트 루트
├── common/                              # 모든 환경 공통 설정
│   ├── spring.profiles.active           # "mysql,aws"
│   └── logging.level.root               # "INFO"
│
├── dev/                                 # 개발 환경
│   ├── db/
│   │   ├── url                          # JDBC URL (Aurora Dev)
│   │   ├── username                     # "petclinic"
│   │   └── secrets-manager-name         # Secrets Manager ARN
│   │
│   ├── customers/
│   │   └── server.port                  # "8080"
│   ├── vets/
│   │   └── server.port                  # "8080"
│   ├── visits/
│   │   └── server.port                  # "8080"
│   └── admin/
│       └── server.port                  # "9090"
│
├── staging/                             # 스테이징 환경 (미래)
│   └── db/
│       └── url                          # JDBC URL (Aurora Staging)
│
└── prod/                                # 프로덕션 환경 (미래)
    └── db/
        └── url                          # JDBC URL (Aurora Prod)
```

**환경별 분리**:
- Dev: `/petclinic-seoul/dev/*`
- Staging: `/petclinic-seoul/staging/*`
- Prod: `/petclinic-seoul/prod/*`

---

## Spring Cloud Config Server 대체

### 기존 아키텍처 (Spring Cloud Config)

```
┌────────────────────────────────────────────────┐
│  Spring Cloud Config Server (ECS 서비스)        │
│  - 별도 컨테이너 실행                           │
│  - Git Repository에서 설정 파일 가져오기         │
│  - 8888 포트로 설정 제공                        │
│  - 리소스 사용: 256 CPU, 512 MB 메모리          │
└────────────────────────────────────────────────┘
              ↓ HTTP 호출
┌────────────────────────────────────────────────┐
│  Microservices (customers, vets, visits)       │
│  - Config Server에서 설정 가져오기              │
│  - 시작 시간 증가 (Config Server 의존)          │
└────────────────────────────────────────────────┘
```

**문제점**:
- Config Server가 단일 장애점 (SPOF)
- 추가 ECS 서비스 운영 비용 (~$20/월)
- 설정 변경 시 Config Server 재시작 필요
- Git Repository 관리 복잡도

---

### 새 아키텍처 (Parameter Store)

```
┌────────────────────────────────────────────────┐
│  AWS Systems Manager Parameter Store          │
│  - AWS 관리형 서비스 (고가용성)                  │
│  - API 기반 설정 조회                           │
│  - 무료 (표준 파라미터)                         │
│  - 버전 관리 자동                               │
└────────────────────────────────────────────────┘
              ↓ AWS SDK 호출
┌────────────────────────────────────────────────┐
│  Microservices (customers, vets, visits)       │
│  - Spring Cloud AWS로 Parameter 자동 로드       │
│  - 빠른 시작 (Config Server 의존성 없음)        │
└────────────────────────────────────────────────┘
```

**장점**:
- ✅ Config Server 제거로 **비용 절감** (~$20/월)
- ✅ **고가용성** (AWS 관리형)
- ✅ **빠른 시작** (HTTP 왕복 불필요)
- ✅ **버전 관리** 자동
- ✅ **IAM 기반 접근 제어**

---

## 우리가 저장하는 파라미터

### 1. 공통 파라미터 (모든 환경)

```hcl
# locals.tf에서 정의
basic_parameters = {
  # Spring 프로파일
  "/petclinic/common/spring.profiles.active" = "mysql,aws"
  
  # 로깅 레벨
  "/petclinic/common/logging.level.root" = "INFO"
  
  # 서비스별 포트 (Dev 환경)
  "/petclinic/dev/customers/server.port" = "8080"
  "/petclinic/dev/vets/server.port"      = "8080"
  "/petclinic/dev/visits/server.port"    = "8080"
  "/petclinic/dev/admin/server.port"     = "9090"  # Admin은 다른 포트
}
```

**실제 Parameter Store에 저장되는 모습**:

| Parameter 이름 | 값 | 타입 | 설명 |
|---------------|-----|------|------|
| `/petclinic-seoul/common/spring.profiles.active` | `mysql,aws` | String | Spring Profile |
| `/petclinic-seoul/common/logging.level.root` | `INFO` | String | Root Logger 레벨 |
| `/petclinic-seoul/dev/customers/server.port` | `8080` | String | Customers 서비스 포트 |
| `/petclinic-seoul/dev/vets/server.port` | `8080` | String | Vets 서비스 포트 |
| `/petclinic-seoul/dev/visits/server.port` | `8080` | String | Visits 서비스 포트 |
| `/petclinic-seoul/dev/admin/server.port` | `9090` | String | Admin 서버 포트 |

---

### 2. 데이터베이스 파라미터 (환경별)

```hcl
# locals.tf - 03-database 레이어에서 엔드포인트 가져옴
database_parameters = {
  # JDBC URL (Aurora 엔드포인트 동적 참조)
  "/petclinic-seoul/dev/db/url" = "jdbc:mysql://${local.aurora_endpoint}:3306/petclinic?useSSL=false&allowPublicKeyRetrieval=true"

  # DB 사용자명
  "/petclinic-seoul/dev/db/username" = var.database_username

  # Secrets Manager ARN (비밀번호 조회용)
  "/petclinic-seoul/dev/db/secrets-manager-name" = data.terraform_remote_state.database.outputs.master_user_secret_name
}
```

**Aurora 엔드포인트 자동 적용**:
```
03-database 레이어 배포
    ↓
Aurora 엔드포인트 생성: petclinic-dev-aurora.cluster-xxx.us-west-2.rds.amazonaws.com
    ↓
04-parameter-store 레이어 배포
    ↓
JDBC URL 자동 생성: jdbc:mysql://petclinic-dev-aurora.cluster-xxx.us-west-2.rds.amazonaws.com:3306/petclinic
```

---

### 3. Parameter 개수

**우리 프로젝트**:
```bash
terraform output parameter_count
# 출력: 8

# 상세:
# - 공통: 2개 (spring.profiles.active, logging.level.root)
# - 서비스 포트: 4개 (customers, vets, visits, admin)
# - 데이터베이스: 2개 (url, username, secrets-manager-name)
```

---

## 애플리케이션 사용 방법

### 1. Spring Boot 의존성

```xml
<!-- pom.xml -->
<dependency>
    <groupId>io.awspring.cloud</groupId>
    <artifactId>spring-cloud-aws-starter-parameter-store</artifactId>
</dependency>
```

---

### 2. application.yml 설정

```yaml
# customers-service/src/main/resources/application.yml
spring:
  application:
    name: customers-service

  # Parameter Store에서 자동 로드
  config:
    import: "aws-parameterstore:/petclinic-seoul/"

  datasource:
    # Parameter Store 값 참조
    url: ${/petclinic-seoul/dev/db/url}
    username: ${/petclinic-seoul/dev/db/username}
    password: ${secretsmanager:${/petclinic-seoul/dev/db/secrets-manager-name}:password::}

server:
  port: ${/petclinic-seoul/dev/customers/server.port}  # 8080

logging:
  level:
    root: ${/petclinic-seoul/common/logging.level.root}  # INFO
```

---

### 3. ECS Task Definition 설정

**IAM 권한 필요** (02-security 레이어에서 생성):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ssm:GetParameter",
        "ssm:GetParameters",
        "ssm:GetParametersByPath"
      ],
      "Resource": "arn:aws:ssm:us-west-2:*:parameter/petclinic-seoul/*"
    }
  ]
}
```

**환경변수 설정** (07-application 레이어):

```hcl
environment = [
  {
    name  = "SPRING_PROFILES_ACTIVE"
    value = "mysql,aws"
  },
  {
    name  = "AWS_REGION"
    value = "us-west-2"
  }
]
```

---

### 4. 실행 흐름

```
1. ECS 컨테이너 시작
   ↓
2. Spring Boot 애플리케이션 초기화
    ↓
3. Spring Cloud AWS가 Parameter Store 접근
    GET /petclinic-seoul/common/spring.profiles.active
    GET /petclinic-seoul/dev/customers/server.port
    GET /petclinic-seoul/dev/db/url
    GET /petclinic-seoul/dev/db/username
   ↓
4. Secrets Manager에서 비밀번호 조회
   GET /secrets/petclinic-dev-aurora-master-password
   ↓
5. DataSource 초기화 (Aurora MySQL 연결)
   ↓
6. 애플리케이션 준비 완료 (포트 8080 리스닝)
```

---

## 코드 구조

### 파일 구성

```
04-parameter-store/
├── main.tf              # Parameter Store 모듈 호출
├── data.tf              # 03-database 레이어 데이터 조회
├── locals.tf            # 파라미터 정의 (basic + database)
├── variables.tf         # 변수 정의
├── outputs.tf           # 출력값
├── backend.tf           # Terraform 상태 저장
├── backend.config       # 백엔드 키 설정
├── terraform.tfvars     # 실제 값 입력
└── README.md            # 이 문서
```

---

### locals.tf - 파라미터 정의

```hcl
locals {
  # Aurora 엔드포인트 조회 (03-database 레이어에서)
  aurora_endpoint = try(
    data.terraform_remote_state.database.outputs.cluster_endpoint,
    ""
  )
  
  # 의존성 검증
  database_ready     = local.aurora_endpoint != ""
  dependencies_ready = local.database_ready
  
  # 기본 공통 설정
  basic_parameters = {
    "/petclinic-seoul/common/spring.profiles.active" = "mysql,aws"
    "/petclinic-seoul/common/logging.level.root"     = "INFO"

    "/petclinic-seoul/${var.environment}/customers/server.port" = "8080"
    "/petclinic-seoul/${var.environment}/vets/server.port"      = "8080"
    "/petclinic-seoul/${var.environment}/visits/server.port"    = "8080"
    "/petclinic-seoul/${var.environment}/admin/server.port"     = "9090"
  }
  
  # 데이터베이스 연결 정보
  database_parameters = local.dependencies_ready ? {
    "/petclinic-seoul/${var.environment}/db/url" =
      "jdbc:mysql://${local.aurora_endpoint}:3306/petclinic?useSSL=false&allowPublicKeyRetrieval=true"

    "/petclinic-seoul/${var.environment}/db/username" = var.database_username

    "/petclinic-seoul/${var.environment}/db/secrets-manager-name" =
      data.terraform_remote_state.database.outputs.master_user_secret_name
  } : {}
  
  # SecureString 파라미터 (현재 사용 안 함)
  secure_parameters = {}
}
```

**포인트**:
- `aurora_endpoint`: 03-database에서 동적으로 가져옴
- `dependencies_ready`: Aurora가 준비되었는지 확인
- `database_parameters`: 의존성이 준비되면 생성

---

### main.tf - 모듈 호출

```hcl
module "parameter_store" {
  source = "../../modules/parameter-store"
  
  name_prefix      = var.name_prefix
  environment      = var.environment
  parameter_prefix = "/petclinic"
  
  # 파라미터 전달
  common_parameters      = local.basic_parameters
  environment_parameters = local.database_parameters
  secure_parameters      = local.secure_parameters
  
  tags = local.common_parameter_tags
}
```

---

## 배포 방법

### 사전 요구사항

1. **03-database 레이어 배포 완료**
```bash
cd ../03-database
terraform output cluster_endpoint
# 출력: petclinic-dev-aurora.cluster-xxx.us-west-2.rds.amazonaws.com
```

---

### 배포 순서

#### 1단계: 작업 디렉토리 이동
```bash
cd terraform/layers/04-parameter-store
```

#### 2단계: 변수 파일 확인
```bash
cat terraform.tfvars
```

예시:
```hcl
# 공통 설정
name_prefix = "petclinic"
environment = "dev"
aws_region  = "us-west-2"
aws_profile = "default"

# Parameter Store 설정
parameter_prefix = "/petclinic-seoul"
database_username = "petclinic"

# 로깅 설정
enable_sql_logging = false  # 프로덕션에서는 false

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
- Parameter 8개 생성 예정
- Aurora 엔드포인트가 정상적으로 참조되는지 확인

#### 5단계: 배포 실행
```bash
terraform apply -var-file=terraform.tfvars
```

**소요 시간**: 약 1분

#### 6단계: 배포 확인
```bash
# 파라미터 개수 확인
terraform output parameter_count
# 8

# Parameter 목록 확인 (AWS CLI)
aws ssm get-parameters-by-path \
  --path "/petclinic/" \
  --recursive \
  --query 'Parameters[*].[Name,Value]' \
  --output table
```

**출력 예시**:
```
--------------------------------------------------------------
| GetParametersByPath                                        |
+------------------------------------------+-----------------+
| /petclinic-seoul/common/spring.profiles.active | mysql,aws       |
| /petclinic-seoul/common/logging.level.root     | INFO            |
| /petclinic-seoul/dev/customers/server.port     | 8080            |
| /petclinic-seoul/dev/vets/server.port          | 8080            |
| /petclinic-seoul/dev/visits/server.port        | 8080            |
| /petclinic-seoul/dev/admin/server.port         | 9090            |
| /petclinic-seoul/dev/db/url                    | jdbc:mysql://...  |
| /petclinic-seoul/dev/db/username               | petclinic       |
| /petclinic-seoul/dev/db/secrets-manager-name   | arn:aws:secret...|
+------------------------------------------+-----------------+
```

---

## 문제 해결

### 문제 1: Aurora 엔드포인트를 찾을 수 없음
```
Error: local.aurora_endpoint is empty
```

**원인**: 03-database 레이어가 배포되지 않음

**해결**:
```bash
cd ../03-database
terraform output cluster_endpoint

# 출력이 없으면 먼저 database 레이어 배포
terraform apply -var-file=terraform.tfvars

# 배포 후 다시 parameter-store 레이어 배포
cd ../04-parameter-store
terraform apply -var-file=terraform.tfvars
```

---

### 문제 2: Parameter가 생성되지 않음
```
Error: error creating SSM parameter: ParameterAlreadyExists
```

**원인**: 이미 동일한 이름의 Parameter 존재

**해결**:
```bash
# 기존 Parameter 확인
aws ssm get-parameter --name "/petclinic/dev/db/url"

# 삭제 후 재생성
aws ssm delete-parameter --name "/petclinic/dev/db/url"

# 또는 Terraform으로 import
terraform import 'module.parameter_store.aws_ssm_parameter.common["/petclinic/dev/db/url"]' /petclinic/dev/db/url
```

---

### 문제 3: ECS에서 Parameter를 읽을 수 없음
```
ERROR: Could not resolve placeholder '/petclinic/dev/db/url'
```

**디버깅 단계**:

1. **IAM 권한 확인**
```bash
# ECS Task Role에 SSM 권한이 있는지 확인
aws iam get-role-policy \
  --role-name petclinic-ecs-task-role \
  --policy-name ParameterStoreAccess
```

2. **Parameter 존재 확인**
```bash
aws ssm get-parameter --name "/petclinic/dev/db/url"
```

3. **Spring 설정 확인**
```yaml
# application.yml에 import 설정 있는지 확인
spring:
  config:
    import: "aws-parameterstore:/petclinic/"
```

4. **환경변수 확인**
```bash
# ECS 컨테이너에서 AWS_REGION 설정되어 있는지
aws ecs describe-task-definition \
  --task-definition petclinic-customers \
  --query 'taskDefinition.containerDefinitions[0].environment'
```

---

### 문제 4: JDBC URL이 잘못됨
```
ERROR: Communications link failure
```

**확인**:
```bash
# Parameter Store에 저장된 JDBC URL 확인
aws ssm get-parameter \
  --name "/petclinic/dev/db/url" \
  --query 'Parameter.Value' \
  --output text

# 예상 출력:
# jdbc:mysql://petclinic-dev-aurora.cluster-xxx.us-west-2.rds.amazonaws.com:3306/petclinic?useSSL=false&allowPublicKeyRetrieval=true

# Aurora 엔드포인트 직접 확인
aws rds describe-db-clusters \
  --db-cluster-identifier petclinic-dev-aurora-cluster \
  --query 'DBClusters[0].Endpoint' \
  --output text
```

**수정**:
```bash
# 잘못된 Parameter 업데이트
aws ssm put-parameter \
  --name "/petclinic/dev/db/url" \
  --value "jdbc:mysql://CORRECT-ENDPOINT:3306/petclinic?useSSL=false&allowPublicKeyRetrieval=true" \
  --overwrite
```

---

### 디버깅 명령어

```bash
# 모든 Parameter 조회
aws ssm describe-parameters \
  --filters "Key=Name,Values=/petclinic/*"

# 특정 Parameter 값 조회
aws ssm get-parameter \
  --name "/petclinic/dev/db/url" \
  --query 'Parameter.Value' \
  --output text

# Parameter 히스토리 확인
aws ssm get-parameter-history \
  --name "/petclinic/dev/db/url"

# Parameter 태그 확인
aws ssm list-tags-for-resource \
  --resource-type "Parameter" \
  --resource-id "/petclinic/dev/db/url"

# Parameter 삭제 (테스트용)
aws ssm delete-parameter --name "/petclinic/dev/db/url"

# Parameter 업데이트
aws ssm put-parameter \
  --name "/petclinic/dev/db/url" \
  --value "new-value" \
  --overwrite
```

---

## 비용 예상

### Parameter Store 비용

| 구성 요소 | 타입 | 개수 | 월 비용 (USD) |
|----------|------|------|---------------|
| Standard Parameters | String | 8개 | $0 (무료) |
| Advanced Parameters | String | 0개 | $0 |
| API 호출 (처리량) | - | < 1,000 TPS | $0 (무료) |
| **합계** | - | - | **$0** |

**무료 티어**:
- Standard Parameter: **10,000개까지 무료**
- API 호출: **1,000 TPS까지 무료**

**Advanced Parameter** (필요 시):
- $0.05/개/월
- 4KB 이상 Parameter 값
- Parameter Policy (자동 만료 등)

**우리 프로젝트**: **무료** (9개 Standard Parameter만 사용)

---

## Config Server 제거로 인한 비용 절감

### 비용 비교

| 항목 | Config Server | Parameter Store | 절감액 |
|------|---------------|-----------------|--------|
| ECS 서비스 | $20/월 | $0 | $20 |
| ALB 리스너 | $16/월 | $0 | $16 |
| CloudWatch Logs | $2/월 | $0 | $2 |
| **합계** | **$38/월** | **$0** | **$38/월** |

**연간 절감액**: **$456/년**

---

## 다음 단계

Parameter Store 레이어 배포가 완료되면:

1. **05-cloud-map**: 서비스 디스커버리 (Eureka 대체)
2. **07-application**: ECS 서비스 배포 (Parameter 사용)

```bash
cd ../05-cloud-map
terraform init -backend-config=../../backend.hcl -backend-config=backend.config
terraform plan -var-file=terraform.tfvars
```

---

## 요약

### 핵심 개념 정리
- ✅ **Parameter Store**: AWS 관리형 설정 저장소
- ✅ **Config Server 대체**: 별도 서버 불필요
- ✅ **중앙 관리**: 모든 설정을 한 곳에서 관리
- ✅ **환경별 분리**: dev/staging/prod 경로 구분

### 생성되는 파라미터
- 공통: 2개 (Spring Profile, 로깅 레벨)
- 서비스 포트: 4개 (customers, vets, visits, admin)
- 데이터베이스: 2개 (JDBC URL, Username, Secrets Manager ARN)
- **합계**: 8개

### 애플리케이션 사용
```yaml
spring:
  config:
    import: "aws-parameterstore:/petclinic/"
  
  datasource:
    url: ${/petclinic/dev/db/url}
    username: ${/petclinic/dev/db/username}
```

### 비용
- **무료** (Standard Parameter 무료 티어)
- Config Server 제거로 **$38/월 절감**

---

**작성일**: 2025-11-20
**작성자**: 황영현
**버전**: 1.1
