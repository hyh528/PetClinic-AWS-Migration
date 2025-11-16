# Terraform Testing Automation Guide

## 📋 목차

1. [개요](#개요)
2. [왜 필요한가?](#왜-필요한가)
3. [테스트 도구 소개](#테스트-도구-소개)
4. [워크플로우 구조](#워크플로우-구조)
5. [동작 원리](#동작-원리)
6. [각 테스트의 역할](#각-테스트의-역할)
7. [설정 파일 설명](#설정-파일-설명)
8. [실행 조건과 트리거](#실행-조건과-트리거)
9. [결과 확인 방법](#결과-확인-방법)
10. [문제 해결](#문제-해결)

---

## 개요

### 무엇인가?

Terraform 코드의 품질과 보안을 자동으로 검증하는 GitHub Actions 워크플로우입니다. 코드가 푸시되거나 Pull Request가 생성될 때마다 자동으로 실행되어 다음을 검사합니다:

- **코드 포맷팅**: Terraform 표준 스타일 준수 여부
- **문법 검증**: Terraform 코드의 문법적 정확성
- **코드 품질**: 네이밍 컨벤션, 사용하지 않는 변수 등
- **보안 취약점**: AWS 리소스의 보안 설정 문제
- **컴플라이언스**: 업계 표준 및 모범 사례 준수

### 파일 위치

```
.github/workflows/terraform-tests.yml  # GitHub Actions 워크플로우
terraform/.tflint.hcl                  # TFLint 설정
terraform/.tfsec.yml                   # TFSec 설정
terraform/.checkov.yml                 # Checkov 설정
terraform/TESTING.md                   # 로컬 테스트 가이드
```

---

## 왜 필요한가?

### 1. 조기 문제 발견

**문제 시나리오**:
```terraform
# 잘못된 코드가 main 브랜치에 머지됨
resource "aws_instance" "web" {
  ami           = "ami-invalid"  # 존재하지 않는 AMI
  instance_type = "t2.invalidtype"  # 잘못된 인스턴스 타입
}
```

**자동화 없이**: 
- `terraform apply` 실행 시점에 발견 (30분 후)
- 이미 코드가 머지되어 롤백 필요
- 다른 팀원들이 영향 받음

**자동화 적용 시**:
- PR 생성 즉시 발견 (30초 후)
- 머지 전에 수정 가능
- 다른 팀원들에게 영향 없음

### 2. 보안 취약점 사전 차단

**취약한 코드 예시**:
```terraform
# 보안 그룹이 모든 IP에 열려있음
resource "aws_security_group" "web" {
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # 위험! 전 세계에 SSH 개방
  }
}
```

**자동화가 감지**:
- TFSec: "SSH port는 특정 IP로 제한해야 함"
- Checkov: "CKV_AWS_260 실패: 보안 그룹 규칙이 너무 관대함"
- PR에 경고 코멘트 자동 생성

### 3. 코드 일관성 유지

**팀 협업 시나리오**:
- 개발자 A: snake_case 사용 (`my_variable`)
- 개발자 B: camelCase 사용 (`myVariable`)
- 개발자 C: kebab-case 사용 (`my-variable`)

**자동화 효과**:
- TFLint가 snake_case로 통일 강제
- 모든 팀원이 동일한 스타일 사용
- 코드 리뷰 시간 단축

### 4. 비용 절감

**실수 예방**:
```terraform
# 실수로 대용량 인스턴스 생성
resource "aws_instance" "dev" {
  instance_type = "r6i.32xlarge"  # 시간당 $10.752
  # 개발 환경인데 프로덕션급 인스턴스 사용
}
```

**자동화 감지**:
- 커스텀 규칙: "개발 환경은 t3.medium 이하만 허용"
- 비용 폭탄 사전 방지

---

## 테스트 도구 소개

### 1. Terraform Format & Validate

#### Terraform Format (`terraform fmt`)

**목적**: 코드 스타일 표준화

**검사 항목**:
- 들여쓰기 (2칸 공백)
- 블록 정렬
- 빈 줄 정리
- 속성 정렬

**예시**:
```terraform
# Before (비표준)
resource "aws_instance" "web" {
instance_type="t3.micro"
  ami = "ami-12345"
    tags={
      Name="Web Server"
    }
}

# After (표준)
resource "aws_instance" "web" {
  ami           = "ami-12345"
  instance_type = "t3.micro"
  
  tags = {
    Name = "Web Server"
  }
}
```

#### Terraform Validate (`terraform validate`)

**목적**: 문법 및 논리적 오류 검증

**검사 항목**:
- HCL 문법 정확성
- 리소스 속성 타입
- 변수 참조 유효성
- 모듈 호출 정확성

**예시**:
```terraform
# 오류 1: 필수 속성 누락
resource "aws_instance" "web" {
  # ami 속성 누락! (필수)
  instance_type = "t3.micro"
}
# Error: Missing required argument

# 오류 2: 존재하지 않는 변수 참조
resource "aws_instance" "web" {
  ami           = var.non_existent_ami
  instance_type = "t3.micro"
}
# Error: Reference to undeclared variable
```

---

### 2. TFLint (Terraform Linter)

**목적**: 코드 품질 및 모범 사례 검증

**공식 사이트**: https://github.com/terraform-linters/tflint

#### 주요 기능

##### A. 네이밍 컨벤션 검사
```terraform
# 잘못된 네이밍
resource "aws_instance" "WebServer" {  # ❌ PascalCase
  ami = var.AMI-ID  # ❌ 대문자와 하이픈
}

# 올바른 네이밍
resource "aws_instance" "web_server" {  # ✅ snake_case
  ami = var.ami_id  # ✅ snake_case
}
```

##### B. 사용하지 않는 선언 감지
```terraform
# 선언했지만 사용하지 않음
variable "unused_var" {  # ⚠️ Warning
  type = string
}

provider "null" {  # ⚠️ 선언했지만 사용하지 않음
  # null 리소스를 생성하지 않음
}
```

##### C. AWS 리소스 검증
```terraform
# 유효하지 않은 인스턴스 타입
resource "aws_instance" "web" {
  instance_type = "t3.invalid"  # ❌ 존재하지 않는 타입
}
# Error: Invalid instance type

# 더 이상 지원되지 않는 타입
resource "aws_instance" "web" {
  instance_type = "t1.micro"  # ⚠️ 구형 타입
}
# Warning: Previous generation instance type
```

##### D. 타입 검사
```terraform
# 타입이 지정되지 않은 변수
variable "instance_count" {  # ⚠️ 타입 미지정
  description = "Number of instances"
}

# 올바른 변수 선언
variable "instance_count" {  # ✅ 타입 명시
  type        = number
  description = "Number of instances"
}
```

#### 플러그인 시스템

TFLint는 플러그인을 통해 확장 가능:

```hcl
# .tflint.hcl
plugin "aws" {
  enabled = true
  version = "0.30.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}
```

**AWS 플러그인 기능**:
- AWS 리소스 타입 검증
- 리전별 AMI 유효성 검사
- 인스턴스 타입 확인
- S3 버킷 네이밍 규칙

---

### 3. TFSec (Terraform Security Scanner)

**목적**: 보안 취약점 스캔

**공식 사이트**: https://github.com/aquasecurity/tfsec

#### 보안 체크 카테고리

##### A. 네트워크 보안
```terraform
# 취약: 모든 IP에 개방
resource "aws_security_group" "web" {
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # 🚨 HIGH severity
  }
}
# TFSec: aws-ec2-no-public-ingress-ssh
# 권장: 특정 IP 범위로 제한

# 안전: 제한된 접근
resource "aws_security_group" "web" {
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]  # ✅ 내부 네트워크만
  }
}
```

##### B. 데이터 암호화
```terraform
# 취약: 암호화되지 않은 S3 버킷
resource "aws_s3_bucket" "data" {
  bucket = "my-data-bucket"
  # 암호화 설정 없음 🚨 HIGH severity
}
# TFSec: aws-s3-enable-bucket-encryption

# 안전: 암호화 활성화
resource "aws_s3_bucket" "data" {
  bucket = "my-data-bucket"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "data" {
  bucket = aws_s3_bucket.data.id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"  # ✅ 암호화 적용
    }
  }
}
```

##### C. 액세스 제어
```terraform
# 취약: 퍼블릭 접근 허용
resource "aws_s3_bucket" "public" {
  bucket = "my-public-bucket"
  acl    = "public-read"  # 🚨 CRITICAL severity
}
# TFSec: aws-s3-no-public-buckets

# 안전: 비공개 버킷
resource "aws_s3_bucket" "private" {
  bucket = "my-private-bucket"
}

resource "aws_s3_bucket_public_access_block" "private" {
  bucket = aws_s3_bucket.private.id
  
  block_public_acls       = true  # ✅ 퍼블릭 ACL 차단
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```

##### D. 로깅 및 모니터링
```terraform
# 권장 사항: CloudTrail 활성화
resource "aws_cloudtrail" "audit" {
  name           = "audit-trail"
  s3_bucket_name = aws_s3_bucket.cloudtrail.id
  
  enable_logging            = true   # ✅ 로깅 활성화
  include_global_service_events = true
  is_multi_region_trail     = true
}
```

#### 심각도 레벨

| 레벨 | 설명 | 예시 |
|------|------|------|
| **CRITICAL** | 즉시 수정 필요 | S3 버킷 퍼블릭 개방 |
| **HIGH** | 높은 우선순위 | SSH 포트 전체 개방 |
| **MEDIUM** | 중간 우선순위 | 로깅 미활성화 |
| **LOW** | 낮은 우선순위 | 태그 누락 |

---

### 4. Checkov (Cloud Security Scanner)

**목적**: 종합 보안 및 컴플라이언스 검사

**공식 사이트**: https://github.com/bridgecrewio/checkov

#### TFSec과의 차이점

| 특징 | TFSec | Checkov |
|------|-------|---------|
| **체크 수** | ~200개 | **600개+** |
| **프레임워크** | Terraform 전용 | Terraform, CloudFormation, K8s, Dockerfile 등 |
| **컴플라이언스** | 기본 보안 | **CIS, PCI-DSS, HIPAA, SOC2** |
| **커스터마이징** | 제한적 | Python으로 커스텀 정책 작성 가능 |
| **실행 속도** | 빠름 | 상대적으로 느림 |

#### 주요 체크 카테고리

##### A. CIS Benchmarks
```terraform
# CKV_AWS_18: S3 버킷 로깅
resource "aws_s3_bucket" "data" {
  bucket = "my-data-bucket"
  # ⚠️ 로깅 미설정
}

# 권장: 로깅 활성화
resource "aws_s3_bucket_logging" "data" {
  bucket = aws_s3_bucket.data.id
  
  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "s3-access-logs/"
}
```

##### B. PCI-DSS 컴플라이언스
```terraform
# CKV_AWS_50: Lambda X-Ray 추적
resource "aws_lambda_function" "payment" {
  function_name = "payment-processor"
  # ⚠️ X-Ray 추적 미활성화
}

# 권장: 추적 활성화 (카드 결제 처리 시 필수)
resource "aws_lambda_function" "payment" {
  function_name = "payment-processor"
  
  tracing_config {
    mode = "Active"  # ✅ X-Ray 활성화
  }
}
```

##### C. IAM 정책 검증
```terraform
# CKV_AWS_63: 너무 관대한 IAM 정책
resource "aws_iam_role_policy" "admin" {
  policy = jsonencode({
    Statement = [{
      Effect   = "Allow"
      Action   = "*"           # 🚨 모든 권한 허용
      Resource = "*"           # 🚨 모든 리소스
    }]
  })
}

# 권장: 최소 권한 원칙
resource "aws_iam_role_policy" "limited" {
  policy = jsonencode({
    Statement = [{
      Effect   = "Allow"
      Action   = [
        "s3:GetObject",        # ✅ 필요한 권한만
        "s3:PutObject"
      ]
      Resource = "arn:aws:s3:::my-bucket/*"  # ✅ 특정 리소스만
    }]
  })
}
```

##### D. 네트워크 세그멘테이션
```terraform
# CKV_AWS_79: ECS 태스크 권한
resource "aws_ecs_task_definition" "app" {
  family = "app"
  
  container_definitions = jsonencode([{
    privileged = true  # 🚨 권한 상승 가능
  }])
}

# 권장: 최소 권한
resource "aws_ecs_task_definition" "app" {
  family = "app"
  
  container_definitions = jsonencode([{
    privileged = false  # ✅ 권한 제한
  }])
}
```

#### Soft-fail 모드

Checkov는 **soft-fail** 모드를 지원하여 경고만 표시하고 빌드는 성공시킬 수 있습니다:

```yaml
# .github/workflows/terraform-tests.yml
- name: Run Checkov
  with:
    soft_fail: true  # 경고만 표시, 빌드는 통과
```

**사용 시나리오**:
- 점진적 보안 개선
- 레거시 코드 마이그레이션
- 개발 환경 테스트

---

## 워크플로우 구조

### 전체 아키텍처

```
GitHub Push/PR
       ↓
┌──────────────────────────────────────┐
│  GitHub Actions Workflow             │
│  (.github/workflows/terraform-tests) │
└──────────────────────────────────────┘
       ↓
┌──────────────────────────────────────┐
│  Parallel Execution (Matrix)         │
│  ├─ bootstrap-oregon                 │
│  ├─ layers/01-network                │
│  ├─ layers/02-security               │
│  └─ ... (13 layers total)            │
└──────────────────────────────────────┘
       ↓
┌─────────────┬─────────────┬──────────────┬──────────────┬──────────────┐
│   Format    │   TFLint    │   TFSec      │   Checkov    │   Docs       │
│   Validate  │             │              │              │   Check      │
└─────────────┴─────────────┴──────────────┴──────────────┴──────────────┘
       ↓             ↓             ↓              ↓              ↓
┌─────────────┬─────────────┬──────────────┬──────────────┬──────────────┐
│   Success   │   Success   │   SARIF      │   SARIF      │   Success    │
│   or Fail   │   or Fail   │   Upload     │   Upload     │   or Fail    │
└─────────────┴─────────────┴──────────────┴──────────────┴──────────────┘
       ↓
┌──────────────────────────────────────┐
│  Test Summary                        │
│  - Format & Validate: ✅             │
│  - TFLint: ✅                        │
│  - TFSec: ✅                         │
│  - Checkov: ✅                       │
│  - Documentation: ✅                 │
└──────────────────────────────────────┘
       ↓
┌──────────────────────────────────────┐
│  GitHub Security Tab                 │
│  - TFSec Results (SARIF)             │
│  - Checkov Results (SARIF)           │
└──────────────────────────────────────┘
```

### Job 구성

워크플로우는 **6개의 독립적인 Job**으로 구성됩니다:

#### 1. terraform-validate
- **실행**: 13개 레이어 병렬 실행
- **시간**: ~30초
- **역할**: 포맷 및 문법 검사

#### 2. tflint
- **실행**: 13개 레이어 병렬 실행
- **시간**: ~45초
- **역할**: 코드 품질 검사

#### 3. tfsec
- **실행**: 전체 terraform 디렉토리 한 번
- **시간**: ~20초
- **역할**: 보안 스캔

#### 4. checkov
- **실행**: 전체 terraform 디렉토리 한 번
- **시간**: ~60초
- **역할**: 컴플라이언스 검사

#### 5. terraform-docs
- **실행**: 13개 레이어 병렬 실행
- **시간**: ~15초
- **역할**: README 존재 확인

#### 6. test-summary
- **실행**: 모든 Job 완료 후
- **시간**: ~5초
- **역할**: 결과 요약

**총 실행 시간**: ~2-3분 (병렬 실행 덕분)

---

## 동작 원리

### 1. 트리거 (Trigger)

워크플로우가 실행되는 조건:

#### A. Pull Request 생성/업데이트
```yaml
on:
  pull_request:
    paths:
      - 'terraform/**'  # terraform 디렉토리 변경 시에만
```

**동작**:
1. PR 생성 시 자동 실행
2. PR에 새 커밋 푸시 시 재실행
3. 결과를 PR 체크로 표시
4. 실패 시 머지 차단 가능

#### B. Push to Main/Develop
```yaml
on:
  push:
    branches:
      - main
      - develop
    paths:
      - 'terraform/**'
```

**동작**:
1. main 또는 develop 브랜치에 직접 푸시 시
2. 머지 후 최종 검증
3. 실패 시 알림

#### C. 수동 실행
```yaml
on:
  workflow_dispatch:  # GitHub UI에서 수동 실행 가능
```

**사용 시나리오**:
- 설정 변경 후 테스트
- 특정 브랜치 검증
- 디버깅

### 2. Matrix Strategy (병렬 실행)

```yaml
strategy:
  fail-fast: false  # 하나 실패해도 나머지 계속 실행
  matrix:
    layer:
      - bootstrap-oregon
      - layers/01-network
      - layers/02-security
      # ... 총 13개
```

**병렬 실행 효과**:
- **순차 실행**: 13개 × 30초 = 6분 30초
- **병렬 실행**: max(30초) = 30초
- **시간 절감**: 약 85%

**fail-fast: false의 중요성**:
```
# fail-fast: true (기본값)
Layer 1: 실패 ❌
Layer 2: 취소 ⏹️
Layer 3: 취소 ⏹️
...
결과: 1개 에러만 확인 가능

# fail-fast: false
Layer 1: 실패 ❌
Layer 2: 성공 ✅
Layer 3: 실패 ❌
...
결과: 모든 에러 한 번에 확인
```

### 3. 경로별 Config 처리

**문제**: `bootstrap-oregon`과 `layers/*`의 디렉토리 깊이가 다름

```
terraform/
├── .tflint.hcl           # Config 파일
├── bootstrap-oregon/     # 1단계 위
└── layers/
    └── 01-network/       # 2단계 위
```

**해결**: 조건부 경로 지정

```yaml
- name: Run TFLint
  run: |
    if [[ "${{ matrix.layer }}" == "bootstrap-oregon" ]]; then
      tflint --config ../.tflint.hcl     # 1단계 위
    else
      tflint --config ../../.tflint.hcl  # 2단계 위
    fi
```

### 4. SARIF 업로드

**SARIF (Static Analysis Results Interchange Format)**:
- 정적 분석 결과 표준 포맷
- GitHub Security 탭에 통합
- 코드와 연결된 상세 정보

```yaml
- name: Run TFSec
  uses: aquasecurity/tfsec-action@v1.0.3
  with:
    format: sarif
    additional_args: --out results.sarif

- name: Upload TFSec SARIF
  uses: github/codeql-action/upload-sarif@v3
  with:
    sarif_file: results.sarif
    category: tfsec
```

**결과**:
- GitHub Security 탭에서 확인
- 파일 라인별로 문제 표시
- 시간 경과에 따른 추이 확인

### 5. PR 코멘트 자동 생성

```yaml
- name: Comment PR (Format Issues)
  if: github.event_name == 'pull_request' && steps.fmt.outcome == 'failure'
  uses: actions/github-script@v7
  with:
    script: |
      github.rest.issues.createComment({
        body: `⚠️ **Terraform Format Check Failed**
        
        Please run:
        \`\`\`bash
        cd terraform/${{ matrix.layer }}
        terraform fmt -recursive
        \`\`\``
      })
```

**효과**:
- PR에 수정 방법 자동 코멘트
- 개발자가 즉시 문제 파악
- 코드 리뷰 부담 감소

---

## 각 테스트의 역할

### 검사 항목 매트릭스

| 항목 | Format | Validate | TFLint | TFSec | Checkov |
|------|--------|----------|--------|-------|---------|
| **들여쓰기** | ✅ | - | - | - | - |
| **문법 오류** | - | ✅ | ✅ | - | - |
| **변수 타입** | - | ✅ | ✅ | - | - |
| **네이밍 컨벤션** | - | - | ✅ | - | - |
| **사용하지 않는 변수** | - | - | ✅ | - | - |
| **AWS 리소스 타입** | - | - | ✅ | - | - |
| **보안 그룹 규칙** | - | - | - | ✅ | ✅ |
| **암호화 설정** | - | - | - | ✅ | ✅ |
| **IAM 권한** | - | - | - | ✅ | ✅ |
| **로깅 설정** | - | - | - | ✅ | ✅ |
| **컴플라이언스** | - | - | - | - | ✅ |
| **모범 사례** | - | - | ✅ | ✅ | ✅ |

### 테스트 우선순위

```
1. terraform fmt (가장 빠름, 기본)
   ↓ 실패 시 여기서 멈춤
   
2. terraform validate (문법 검증)
   ↓ 통과
   
3. TFLint (코드 품질)
   ↓ 병렬 실행
   
4. TFSec + Checkov (보안)
   ↓ 동시 실행
   
5. terraform-docs (문서화)
```

---

## 설정 파일 설명

### 1. .tflint.hcl

```hcl
# TFLint 전역 설정
config {
  call_module_type = "all"        # 모든 모듈 검사
  force            = false        # 경고를 에러로 처리하지 않음
}

# Terraform 기본 플러그인
plugin "terraform" {
  enabled = true
  preset  = "recommended"         # 추천 규칙 사용
}

# AWS 플러그인
plugin "aws" {
  enabled = true
  version = "0.30.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

# 네이밍 컨벤션
rule "terraform_naming_convention" {
  enabled = true
  
  variable {
    format = "snake_case"         # my_variable
  }
  
  resource {
    format = "snake_case"         # aws_instance.my_instance
  }
}

# 사용하지 않는 선언 (비활성화)
rule "terraform_unused_declarations" {
  enabled = false                 # 미래에 사용할 수 있는 변수 허용
}
```

**커스터마이징**:
```hcl
# 프로젝트별 규칙 추가
rule "custom_instance_type" {
  enabled = true
  
  # t3, t4 패밀리만 허용
  allowed_instance_families = ["t3", "t4g"]
}
```

### 2. .tfsec.yml

```yaml
# 최소 심각도 설정
minimum_severity: MEDIUM  # LOW는 무시

# 특정 체크 제외
exclude:
  # 비용 최적화를 위해 로깅 비활성화
  - aws-s3-enable-bucket-logging
  
  # 개발 환경에서는 불필요
  - aws-ec2-require-vpc-flow-logs-for-all-vpcs
  
  # CloudFront는 프로덕션에서만 WAF 사용
  - aws-cloudfront-enable-waf

# 특정 경로 제외
exclude_paths:
  - "**/.terraform/**"
  - "**/node_modules/**"
```

**심각도별 정책**:
```yaml
# 프로덕션 환경
minimum_severity: HIGH

# 개발 환경
minimum_severity: MEDIUM

# 로컬 테스트
minimum_severity: LOW
```

### 3. .checkov.yml

```yaml
# 프레임워크 지정
framework:
  - terraform
  - secrets  # 하드코딩된 시크릿 감지

# 제외할 체크
skip-check:
  # S3 로깅 (비용 절감)
  - CKV_AWS_18
  
  # Lambda X-Ray (개발 환경)
  - CKV_AWS_50
  
  # ECS 태스크 권한 (개발 환경)
  - CKV_AWS_79

# Soft-fail 모드
soft-fail: true  # 경고만 표시, 빌드 통과

# 출력 형식
output:
  - cli      # 콘솔 출력
  - sarif    # GitHub Security 업로드

# 병렬 처리
parallel: true
```

**환경별 설정**:
```yaml
# 개발 환경
soft-fail: true
skip-check: [CKV_AWS_18, CKV_AWS_50]

# 프로덕션 환경
soft-fail: false  # 실패 시 빌드 중단
skip-check: []    # 모든 체크 실행
```

---

## 실행 조건과 트리거

### 언제 실행되는가?

#### 1. Pull Request 이벤트

```yaml
on:
  pull_request:
    paths:
      - 'terraform/**'
```

**트리거 조건**:
- PR 생성
- PR에 새 커밋 푸시
- PR 재오픈
- `terraform/` 디렉토리 파일 변경

**실행되지 않는 경우**:
```
변경된 파일:
- src/main.py          ❌ (애플리케이션 코드)
- docs/README.md       ❌ (문서)
- .github/workflows/   ❌ (다른 워크플로우)
```

#### 2. Push 이벤트

```yaml
on:
  push:
    branches:
      - main
      - develop
```

**사용 시나리오**:
1. PR 머지 후 최종 검증
2. Direct push 시 검증
3. 정기적인 보안 스캔

#### 3. 스케줄 실행 (선택사항)

```yaml
on:
  schedule:
    - cron: '0 0 * * 0'  # 매주 일요일 자정
```

**용도**:
- 정기 보안 감사
- 최신 규칙으로 재검증
- 컴플라이언스 보고서 생성

### 실행 시간 최적화

#### 캐싱 전략

```yaml
- name: Cache TFLint plugins
  uses: actions/cache@v3
  with:
    path: ~/.tflint.d/plugins
    key: tflint-${{ hashFiles('**/.tflint.hcl') }}
```

**효과**:
- 첫 실행: 60초 (플러그인 다운로드)
- 이후 실행: 10초 (캐시 사용)

#### 조건부 실행

```yaml
- name: Run TFSec
  if: github.event_name == 'pull_request'  # PR에서만 실행
```

---

## 결과 확인 방법

### 1. GitHub Actions 탭

**위치**: Repository → Actions 탭

**표시 정보**:
- 워크플로우 실행 목록
- 각 Job의 성공/실패 상태
- 실행 시간
- 로그 상세 내용

**네비게이션**:
```
Actions
  └─ Terraform Tests
       ├─ Run #123 (4 minutes ago)
       │    ├─ terraform-validate (13개) ✅
       │    ├─ tflint (13개) ✅
       │    ├─ tfsec ✅
       │    ├─ checkov ✅
       │    └─ terraform-docs (13개) ✅
       │
       └─ Run #122 (1 hour ago) ❌
            ├─ terraform-validate (13개) ✅
            ├─ tflint (13개) ❌ (3 failed)
            ├─ tfsec ✅
            ├─ checkov ⚠️ (warnings)
            └─ terraform-docs (13개) ✅
```

### 2. Pull Request 체크

**PR 화면**:
```
Checks: 5 / 5 passing

✅ Format & Validate (13 layers)
✅ TFLint (13 layers)
✅ TFSec
✅ Checkov
✅ Documentation
```

**실패 시**:
```
Checks: 3 / 5 failing

✅ Format & Validate (13 layers)
❌ TFLint (3 layers failed)
   └─ layers/06-lambda-genai: Missing version constraint
✅ TFSec
⚠️ Checkov (12 warnings)
   └─ View details
✅ Documentation
```

### 3. GitHub Security 탭

**위치**: Repository → Security → Code scanning

**표시 정보**:
- TFSec 발견 사항
- Checkov 발견 사항
- 심각도별 분류
- 시간 경과 추이

**예시**:
```
Open alerts: 5

HIGH (2)
├─ S3 bucket publicly accessible
│  File: terraform/layers/11-frontend/main.tf:42
│  Found by: TFSec
│
└─ Security group allows ingress from 0.0.0.0/0
   File: terraform/layers/02-security/main.tf:18
   Found by: Checkov

MEDIUM (3)
├─ CloudWatch log group not encrypted
├─ S3 bucket logging not enabled
└─ VPC flow logs not enabled
```

### 4. 테스트 요약 (Summary)

**워크플로우 실행 후 자동 생성**:

```markdown
## Terraform Test Results

| Test | Status |
|------|--------|
| Format & Validate | ✅ success |
| TFLint | ✅ success |
| TFSec | ✅ success |
| Checkov | ✅ success |
| Documentation | ✅ success |

All tests passed! 🎉
```

---

## 문제 해결

### 자주 발생하는 문제

#### 1. TFLint Plugin 오류

**증상**:
```
Failed to initialize plugins; Plugin "aws" not found
```

**원인**: `.tflint.hcl`에 AWS plugin 정의했지만 `tflint --init` 미실행

**해결**:
```yaml
- name: Initialize TFLint
  run: tflint --init --config ../../.tflint.hcl  # config 경로 필수
```

#### 2. Config 파일 경로 오류

**증상**:
```
Failed to load TFLint config; open ../../.tflint.hcl: no such file or directory
```

**원인**: `bootstrap-oregon`과 `layers/*`의 경로 깊이 차이

**해결**:
```yaml
- name: Run TFLint
  run: |
    if [[ "${{ matrix.layer }}" == "bootstrap-oregon" ]]; then
      tflint --config ../.tflint.hcl     # 1단계 위
    else
      tflint --config ../../.tflint.hcl  # 2단계 위
    fi
```

#### 3. Terraform 버전 불일치

**증상**:
```
Error: Unsupported Terraform Core version
This configuration does not support Terraform version 1.10.0
required_version = ">= 1.12.0"
```

**해결**:
```yaml
- name: Setup Terraform
  uses: hashicorp/setup-terraform@v3
  with:
    terraform_version: 1.12.0  # 코드의 required_version과 일치
```

#### 4. SARIF 업로드 실패

**증상**:
```
Error: Path does not exist: results.sarif
```

**원인**: TFSec/Checkov가 SARIF 파일 생성 실패

**해결**:
```yaml
- name: Upload TFSec SARIF
  if: always() && hashFiles('results.sarif') != ''  # 파일 존재 확인
  uses: github/codeql-action/upload-sarif@v3
```

#### 5. 사용하지 않는 변수로 실패

**증상**:
```
variable "unused_var" is declared but not used
Process completed with exit code 2
```

**해결 방법 1** (규칙 비활성화):
```hcl
# .tflint.hcl
rule "terraform_unused_declarations" {
  enabled = false  # 미래 사용을 위한 변수 허용
}
```

**해결 방법 2** (변수 제거):
```terraform
# 실제로 사용하지 않을 변수 삭제
# variable "unused_var" { ... }  # 삭제
```

### 디버깅 팁

#### 1. 로컬에서 재현

```bash
# 로컬에서 동일한 테스트 실행
cd terraform/layers/06-lambda-genai

# Format 체크
terraform fmt -check -recursive

# Validate
terraform init -backend=false
terraform validate

# TFLint
tflint --init --config ../../.tflint.hcl
tflint --format compact --config ../../.tflint.hcl

# TFSec (전체 디렉토리)
cd ../..
tfsec --config-file .tfsec.yml

# Checkov (전체 디렉토리)
checkov -d . --config-file .checkov.yml
```

#### 2. 상세 로그 확인

```yaml
# 디버그 모드 활성화
- name: Run TFLint
  run: tflint --loglevel=debug --config ../../.tflint.hcl
```

#### 3. 특정 레이어만 테스트

```yaml
# matrix를 특정 레이어로 제한
strategy:
  matrix:
    layer:
      - layers/06-lambda-genai  # 문제가 있는 레이어만
```

---

## 모범 사례

### 1. 점진적 엄격화

**단계별 접근**:

**Phase 1** (초기 도입):
```yaml
# TFSec: MEDIUM 이상만
minimum_severity: MEDIUM

# Checkov: soft-fail 모드
soft-fail: true

# TFLint: unused 규칙 비활성화
terraform_unused_declarations: false
```

**Phase 2** (안정화):
```yaml
# TFSec: HIGH 이상으로 상향
minimum_severity: HIGH

# Checkov: 일부 규칙 적용
soft-fail: false
skip-check: [CKV_AWS_18]  # 중요한 것만 제외
```

**Phase 3** (성숙):
```yaml
# TFSec: 모든 심각도
minimum_severity: LOW

# Checkov: 모든 규칙 적용
soft-fail: false
skip-check: []
```

### 2. 환경별 설정

```yaml
# 개발 환경
- uses: tfsec-action
  with:
    soft_fail: true
    minimum_severity: MEDIUM

# 프로덕션 환경
- uses: tfsec-action
  with:
    soft_fail: false
    minimum_severity: HIGH
```

### 3. 정기 리뷰

```yaml
# 매주 전체 스캔
on:
  schedule:
    - cron: '0 0 * * 0'  # 일요일
  workflow_dispatch:     # 수동 실행도 가능
```

**리뷰 항목**:
- 새로운 보안 규칙 적용
- 제외 규칙 재검토
- 경고 사항 정리

### 4. 문서화

각 제외 규칙에 이유 명시:

```yaml
exclude:
  # S3 로깅: 개발 환경에서 비용 절감 목적
  # TODO: 프로덕션에서는 활성화 필요
  - aws-s3-enable-bucket-logging
  
  # CloudFront WAF: 낮은 트래픽으로 현재 불필요
  # 월 방문자 1000명 이상 시 활성화 검토
  - aws-cloudfront-enable-waf
```

---

## 성능 최적화

### 실행 시간 측정

| Job | 순차 실행 | 병렬 실행 | 절감 |
|-----|----------|----------|------|
| terraform-validate | 13 × 30s = 6.5분 | 30s | 92% |
| tflint | 13 × 45s = 9.75분 | 45s | 92% |
| tfsec | 60s | 60s | 0% |
| checkov | 120s | 120s | 0% |
| terraform-docs | 13 × 10s = 2.2분 | 10s | 91% |
| **합계** | **20.5분** | **~3분** | **85%** |

### 추가 최적화

#### 1. Incremental Testing

변경된 레이어만 테스트:

```yaml
- name: Get changed files
  id: changed
  uses: tj-actions/changed-files@v40
  with:
    files: terraform/**

- name: Run TFLint on changed layers only
  if: steps.changed.outputs.any_changed == 'true'
  run: |
    for file in ${{ steps.changed.outputs.all_changed_files }}; do
      layer=$(dirname $file | cut -d/ -f1-2)
      cd $layer && tflint
    done
```

#### 2. 캐시 활용

```yaml
- name: Cache Terraform providers
  uses: actions/cache@v3
  with:
    path: |
      ~/.terraform.d/plugins
      **/.terraform/providers
    key: terraform-providers-${{ hashFiles('**/*.tf') }}

- name: Cache TFLint plugins
  uses: actions/cache@v3
  with:
    path: ~/.tflint.d/plugins
    key: tflint-${{ hashFiles('**/.tflint.hcl') }}
```

---

## 확장 및 커스터마이징

### 커스텀 TFLint 규칙

Python으로 커스텀 규칙 작성:

```python
# custom_rules/instance_naming.py
from tflint import Rule, Issue

class InstanceNamingRule(Rule):
    name = "custom_instance_naming"
    severity = "ERROR"
    
    def check_resource(self, resource):
        if resource.type == "aws_instance":
            name = resource.config.get("tags", {}).get("Name", "")
            if not name.startswith("petclinic-"):
                return Issue(
                    message="Instance name must start with 'petclinic-'",
                    file=resource.file,
                    line=resource.line
                )
```

### 커스텀 Checkov 정책

```python
# custom_policies/require_backup_tags.py
from checkov.terraform.checks.resource.base_resource_check import BaseResourceCheck

class RequireBackupTags(BaseResourceCheck):
    def __init__(self):
        name = "Ensure all resources have backup tags"
        id = "CKV_CUSTOM_1"
        supported_resources = ['aws_instance', 'aws_db_instance']
        categories = ['backup']
        super().__init__(name=name, id=id, categories=categories, 
                         supported_resources=supported_resources)
    
    def scan_resource_conf(self, conf):
        tags = conf.get('tags', [{}])[0]
        return 'Backup' in tags and 'BackupSchedule' in tags
```

### 알림 통합

#### Slack 알림

```yaml
- name: Slack Notification
  if: failure()
  uses: 8398a7/action-slack@v3
  with:
    status: ${{ job.status }}
    text: |
      Terraform tests failed!
      
      Failed tests:
      - TFLint: ${{ needs.tflint.result }}
      - TFSec: ${{ needs.tfsec.result }}
      
      View details: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}
```

#### 이메일 알림

```yaml
- name: Send email
  if: failure()
  uses: dawidd6/action-send-mail@v3
  with:
    server_address: smtp.gmail.com
    server_port: 465
    username: ${{ secrets.EMAIL_USERNAME }}
    password: ${{ secrets.EMAIL_PASSWORD }}
    subject: Terraform Tests Failed - ${{ github.repository }}
    body: |
      Terraform security tests failed.
      Please check: ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}
```

---

## 참고 자료

### 공식 문서

- **Terraform**: https://www.terraform.io/docs
- **TFLint**: https://github.com/terraform-linters/tflint
- **TFSec**: https://aquasecurity.github.io/tfsec
- **Checkov**: https://www.checkov.io/
- **GitHub Actions**: https://docs.github.com/en/actions

### 관련 표준

- **CIS Benchmarks**: https://www.cisecurity.org/cis-benchmarks
- **AWS Well-Architected**: https://aws.amazon.com/architecture/well-architected
- **OWASP**: https://owasp.org/

### 프로젝트 내 문서

- `terraform/TESTING.md` - 로컬 테스트 가이드
- `terraform/.tflint.hcl` - TFLint 설정
- `terraform/.tfsec.yml` - TFSec 설정
- `terraform/.checkov.yml` - Checkov 설정

---

## 결론

Terraform Testing Automation은:

1. ✅ **조기 문제 발견**: PR 단계에서 오류 감지
2. ✅ **보안 강화**: 600+ 보안 체크로 취약점 차단
3. ✅ **코드 품질**: 일관된 스타일과 모범 사례 적용
4. ✅ **시간 절약**: 자동화로 수동 검토 부담 감소
5. ✅ **비용 절감**: 프로덕션 배포 전 문제 발견

**권장 사항**:
- 모든 Terraform 프로젝트에 적용
- 점진적으로 규칙 엄격화
- 정기적인 설정 리뷰
- 팀원 교육 및 문서화

**다음 단계**:
1. 로컬에서 테스트 실행해보기 (`terraform/TESTING.md` 참조)
2. 첫 PR 생성하여 자동화 확인
3. GitHub Security 탭에서 결과 검토
4. 필요에 따라 규칙 커스터마이징

---

**문서 버전**: 1.0  
**최종 업데이트**: 2025-11-09  
**작성자**: GenSpark AI Developer
