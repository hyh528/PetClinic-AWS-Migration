# Terraform 보안 모범 사례 가이드

## 개요

본 문서는 Terraform을 사용한 인프라 관리 시 필수적으로 적용해야 하는 보안 모범 사례를 다룹니다. 특히 Secrets Manager와 같은 민감한 정보를 다루는 리소스에서 발생할 수 있는 실제 운영 문제들과 해결 방법을 상세히 설명합니다.

**주요 내용:**
- Lifecycle 관리의 필요성과 적용 방법
- Sensitive 변수 설정의 중요성
- 실제 운영 환경에서 발생하는 보안 문제 사례
- 실무 적용 가이드라인

---

## 1. Lifecycle 관리 (ignore_changes)

### 문제 상황: Terraform 드리프트 문제

#### 시나리오: 데이터베이스 비밀번호 관리

**1단계: 초기 Terraform 배포**
```hcl
# 문제가 있는 코드 (lifecycle 없음)
resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db.id
  secret_string = "initial-password-123"
}
```

**2단계: 운영 중 보안팀에서 비밀번호 변경**
```bash
# AWS CLI로 비밀번호 변경
aws secretsmanager update-secret \
  --secret-id petclinic-db-password \
  --secret-string "new-secure-password-2024"

# 또는 AWS 콘솔에서 수동 변경
# Console: initial-password-123 → new-secure-password-2024
```

**3단계: 개발팀에서 인프라 업데이트 시도**
```bash
$ terraform plan

# 😱 문제 발생!
Terraform will perform the following actions:

  # aws_secretsmanager_secret_version.db_password will be updated in-place
  ~ resource "aws_secretsmanager_secret_version" "db_password" {
      ~ secret_string = "new-secure-password-2024" -> "initial-password-123"
    }

Plan: 0 to add, 1 to change, 0 to destroy.
```

**4단계: terraform apply 실행 시 재앙**
```bash
$ terraform apply

# 💥 실제 운영 중인 비밀번호가 초기값으로 되돌아감!
# 모든 애플리케이션의 데이터베이스 연결 실패!
# 서비스 장애 발생!
```

### 해결책: Lifecycle ignore_changes

```hcl
# ✅ 올바른 코드
resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db.id
  secret_string = var.secret_string_value

  lifecycle {
    ignore_changes = [secret_string]
  }
}
```

**결과:**
```bash
$ terraform plan

No changes. Your infrastructure matches the configuration.

# ✅ Terraform이 secret_string 변경을 무시함
# ✅ 다른 설정(태그, 설명 등)은 여전히 관리됨
# ✅ 운영 중인 비밀번호는 안전하게 보호됨
```

### Lifecycle 적용 시나리오

#### 1. 민감한 데이터
```hcl
# Secrets Manager
lifecycle {
  ignore_changes = [secret_string]
}

# RDS 비밀번호 (수동 변경 후)
lifecycle {
  ignore_changes = [password]
}
```

#### 2. 자동 생성되는 값
```hcl
# Auto Scaling Group (인스턴스 수가 자동 조정됨)
lifecycle {
  ignore_changes = [desired_capacity]
}

# ECS Service (태스크 수가 자동 스케일링됨)
lifecycle {
  ignore_changes = [desired_count]
}
```

#### 3. 외부에서 관리되는 설정
```hcl
# Lambda 함수 (CI/CD에서 코드 배포)
lifecycle {
  ignore_changes = [source_code_hash, last_modified]
}
```

---

## 2. Sensitive 변수 설정

### 문제 상황: 민감 정보 노출

#### 시나리오 1: Terraform 로그 노출

**문제가 있는 코드:**
```hcl
variable "database_password" {
  description = "데이터베이스 비밀번호"
  type        = string
  default     = "super-secret-password"
  # sensitive = true 누락! 🚨
}

output "db_connection_string" {
  value = "mysql://user:${var.database_password}@${aws_db_instance.main.endpoint}/db"
}
```

**실행 결과:**
```bash
$ terraform apply

Apply complete! Resources: 1 added, 0 changed, 0 destroyed.

Outputs:

db_connection_string = "mysql://user:super-secret-password@db.amazonaws.com/db"
# 🚨 비밀번호가 터미널에 그대로 노출!
```

#### 시나리오 2: CI/CD 파이프라인 로그 노출

**GitHub Actions 워크플로우:**
```yaml
name: Deploy Infrastructure
on: [push]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Terraform Apply
        run: terraform apply -auto-approve
        env:
          TF_VAR_database_password: ${{ secrets.DB_PASSWORD }}
```

**GitHub Actions 로그:**
```
Run terraform apply -auto-approve

Terraform will perform the following actions:
  # aws_db_instance.main will be created
  + resource "aws_db_instance" "main" {
      + password = "super-secret-password"  # 🚨 로그에 노출!
    }

Apply complete! Resources: 1 added, 0 changed, 0 destroyed.
```

#### 시나리오 3: Terraform State 파일 노출

**terraform.tfstate 파일:**
```json
{
  "version": 4,
  "terraform_version": "1.0.0",
  "resources": [
    {
      "type": "aws_db_instance",
      "values": {
        "password": "super-secret-password",  // 🚨 평문으로 저장!
        "username": "admin"
      }
    }
  ]
}
```

### 해결책: Sensitive 변수 설정

```hcl
# ✅ 올바른 코드
variable "database_password" {
  description = "데이터베이스 비밀번호"
  type        = string
  sensitive   = true  # 🔒 보안 설정
}

output "db_connection_info" {
  value = {
    endpoint = aws_db_instance.main.endpoint
    port     = aws_db_instance.main.port
    # 비밀번호는 출력하지 않음
  }
}

# 만약 꼭 출력해야 한다면
output "db_password" {
  value     = var.database_password
  sensitive = true  # 🔒 출력도 민감 정보로 설정
}
```

**실행 결과:**
```bash
$ terraform apply

Apply complete! Resources: 1 added, 0 changed, 0 destroyed.

Outputs:

db_connection_info = {
  "endpoint" = "db.amazonaws.com"
  "port" = 3306
}
db_password = <sensitive>  # 🔒 값이 숨겨짐
```

**GitHub Actions 로그:**
```
Run terraform apply -auto-approve

Terraform will perform the following actions:
  # aws_db_instance.main will be created
  + resource "aws_db_instance" "main" {
      + password = (sensitive value)  # 🔒 안전하게 숨겨짐
    }

Apply complete! Resources: 1 added, 0 destroyed.
```

---

## 3. 실제 운영 시나리오

### 시나리오 1: 정기적인 비밀번호 로테이션

**상황:** 보안 정책에 따라 매월 데이터베이스 비밀번호 변경

```bash
# 1. 보안팀에서 AWS CLI로 비밀번호 변경
aws secretsmanager update-secret \
  --secret-id prod-db-password \
  --secret-string "$(openssl rand -base64 32)"

# 2. 애플리케이션 자동 재시작 (새 비밀번호 적용)
kubectl rollout restart deployment/petclinic-app

# 3. 개발팀에서 인프라 업데이트
terraform plan  # lifecycle 덕분에 비밀번호 변경 무시 ✅
terraform apply # 다른 설정만 업데이트됨
```

**lifecycle 없었다면:**
```bash
terraform plan
# 💥 비밀번호를 초기값으로 되돌리려고 시도
# 💥 apply 시 서비스 장애 발생
```

### 시나리오 2: 멀티 환경 배포

**디렉토리 구조:**
```
environments/
├── dev/
│   ├── terraform.tfvars
│   └── main.tf
├── staging/
│   ├── terraform.tfvars
│   └── main.tf
└── prod/
    ├── terraform.tfvars
    └── main.tf
```

**각 환경별 설정:**
```hcl
# environments/prod/terraform.tfvars
database_password = "prod-super-secure-password"  # 🚨 위험!
```

**올바른 방법:**
```hcl
# environments/prod/terraform.tfvars
# 비밀번호는 환경변수나 외부 시스템에서 주입
# database_password는 TF_VAR_database_password 환경변수로 설정

# variables.tf
variable "database_password" {
  description = "데이터베이스 비밀번호"
  type        = string
  sensitive   = true  # 🔒 필수!
}
```

**CI/CD 파이프라인:**
```yaml
# .github/workflows/deploy.yml
- name: Deploy to Production
  run: terraform apply -auto-approve
  env:
    TF_VAR_database_password: ${{ secrets.PROD_DB_PASSWORD }}
  # 🔒 GitHub Secrets에서 안전하게 주입
```

### 시나리오 3: 팀 협업 환경

**문제 상황:**
```bash
# 개발자 A가 실행
$ terraform plan
# 로그에 비밀번호 노출 🚨

# 개발자 B가 같은 터미널 사용
$ history
# 이전 명령어에서 비밀번호 확인 가능 🚨
```

**해결책:**
```hcl
# 모든 민감 변수에 sensitive = true 설정
variable "api_key" {
  type      = string
  sensitive = true
}

variable "database_password" {
  type      = string
  sensitive = true
}

variable "jwt_secret" {
  type      = string
  sensitive = true
}
```

---

## 4. 보안 체크리스트

### Terraform 코드 작성 시

#### ✅ 필수 확인사항
- [ ] 모든 비밀번호, API 키, 토큰에 `sensitive = true` 설정
- [ ] 외부에서 변경되는 값에 `lifecycle { ignore_changes = [...] }` 설정
- [ ] `.tfvars` 파일을 `.gitignore`에 추가
- [ ] State 파일을 원격 백엔드(S3 + DynamoDB)에 저장
- [ ] State 파일 암호화 활성화

#### ✅ 변수 설정 가이드라인
```hcl
# 🔒 민감 정보 (반드시 sensitive = true)
variable "database_password" { sensitive = true }
variable "api_key" { sensitive = true }
variable "private_key" { sensitive = true }
variable "jwt_secret" { sensitive = true }

# 🌐 공개 정보 (sensitive 불필요)
variable "project_name" { }
variable "environment" { }
variable "region" { }
variable "instance_type" { }
```

#### ✅ Lifecycle 설정 가이드라인
```hcl
# 🔄 외부에서 변경되는 값들
lifecycle {
  ignore_changes = [
    secret_string,        # Secrets Manager
    password,            # RDS 비밀번호
    desired_capacity,    # Auto Scaling
    desired_count,       # ECS Service
    source_code_hash,    # Lambda 함수
    last_modified        # 자동 업데이트되는 값들
  ]
}
```

### CI/CD 파이프라인 설정 시

#### ✅ GitHub Actions
```yaml
env:
  # 🔒 GitHub Secrets 사용
  TF_VAR_database_password: ${{ secrets.DB_PASSWORD }}
  TF_VAR_api_key: ${{ secrets.API_KEY }}
  
  # 🌐 일반 환경변수
  TF_VAR_project_name: "petclinic"
  TF_VAR_environment: "prod"
```

#### ✅ 로그 보안
- Terraform 출력에서 `<sensitive>` 표시 확인
- 실제 값이 로그에 노출되지 않는지 검증
- 히스토리 명령어에서 민감 정보 제거

---

## 5. 실무 팁과 주의사항

### 일반적인 실수들

#### ❌ 흔한 실수 1: 출력값에서 민감 정보 노출
```hcl
# 잘못된 예
output "database_url" {
  value = "mysql://user:${var.database_password}@${aws_db_instance.main.endpoint}/db"
  # sensitive = true 누락!
}
```

#### ❌ 흔한 실수 2: 조건부 민감 정보
```hcl
# 잘못된 예
output "debug_info" {
  value = var.environment == "dev" ? var.database_password : "hidden"
  # dev 환경에서 비밀번호 노출!
}
```

#### ❌ 흔한 실수 3: 로컬 값에서 민감 정보 처리
```hcl
# 잘못된 예
locals {
  connection_string = "mysql://user:${var.database_password}@${aws_db_instance.main.endpoint}/db"
  # locals는 sensitive 설정 불가!
}
```

### 올바른 해결책

#### ✅ 올바른 출력값 처리
```hcl
output "database_endpoint" {
  value = aws_db_instance.main.endpoint
  # 비밀번호는 별도로 관리
}

output "database_password" {
  value     = var.database_password
  sensitive = true
}
```

#### ✅ 조건부 처리
```hcl
output "debug_info" {
  value     = var.environment == "dev" ? var.database_password : null
  sensitive = true  # 모든 경우에 민감 정보로 처리
}
```

#### ✅ 로컬 값 처리
```hcl
# 민감한 로컬 값은 사용하지 않거나
# 리소스 내부에서 직접 참조
resource "aws_ecs_task_definition" "app" {
  container_definitions = jsonencode([{
    environment = [
      {
        name  = "DB_HOST"
        value = aws_db_instance.main.endpoint
      }
      # 비밀번호는 secrets로 별도 관리
    ]
    secrets = [
      {
        name      = "DB_PASSWORD"
        valueFrom = aws_secretsmanager_secret.db.arn
      }
    ]
  }])
}
```

---

## 6. 마이그레이션 가이드

### 기존 코드에 보안 설정 추가하기

#### 1단계: 민감 변수 식별
```bash
# 기존 코드에서 민감한 변수 찾기
grep -r "password\|key\|secret\|token" *.tf
```

#### 2단계: Sensitive 설정 추가
```hcl
# Before
variable "db_password" {
  type = string
}

# After
variable "db_password" {
  type      = string
  sensitive = true  # 추가
}
```

#### 3단계: Lifecycle 설정 추가
```hcl
# Before
resource "aws_secretsmanager_secret_version" "this" {
  secret_id     = aws_secretsmanager_secret.this.id
  secret_string = var.secret_value
}

# After
resource "aws_secretsmanager_secret_version" "this" {
  secret_id     = aws_secretsmanager_secret.this.id
  secret_string = var.secret_value
  
  lifecycle {
    ignore_changes = [secret_string]  # 추가
  }
}
```

#### 4단계: 점진적 적용
```bash
# 1. 개발 환경에서 먼저 테스트
cd environments/dev
terraform plan  # 변경사항 확인
terraform apply

# 2. 스테이징 환경 적용
cd ../staging
terraform plan
terraform apply

# 3. 프로덕션 환경 적용
cd ../prod
terraform plan  # 신중하게 검토
terraform apply
```

---

## 결론

Terraform에서 민감한 정보를 다룰 때는 **Lifecycle 관리**와 **Sensitive 변수 설정**이 필수입니다. 이는 단순한 보안 설정이 아니라 **실제 운영 환경에서 서비스 장애를 방지**하고 **정보 유출을 막는** 핵심적인 보안 조치입니다.

### 핵심 원칙
1. **모든 민감 정보에 `sensitive = true` 설정**
2. **외부에서 변경되는 값에 `lifecycle { ignore_changes }` 설정**
3. **CI/CD 파이프라인에서 환경변수로 민감 정보 주입**
4. **정기적인 보안 검토 및 테스트**

### 실무 적용
- 개발 초기부터 보안 설정 적용
- 코드 리뷰 시 보안 체크리스트 확인
- 운영 환경 배포 전 보안 검증
- 팀 내 보안 가이드라인 공유

이러한 보안 모범 사례를 통해 **안전하고 신뢰할 수 있는 인프라 관리**가 가능합니다.

---

**문서 작성일**: 2025년 1월 4일  
**작성자**: 영현  
**대상**: Terraform 보안 모범 사례  
**버전**: 1.0