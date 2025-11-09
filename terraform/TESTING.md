# Terraform 테스트 자동화 🧪

## 목차
- [개요](#개요)
- [테스트 도구 소개](#테스트-도구-소개)
- [GitHub Actions 자동화](#github-actions-자동화)
- [로컬에서 테스트 실행](#로컬에서-테스트-실행)
- [테스트 규칙 커스터마이징](#테스트-규칙-커스터마이징)
- [문제 해결](#문제-해결)

---

## 개요

**Terraform 코드 품질 및 보안 검사**를 자동화하여 배포 전 문제를 조기에 발견합니다.

### 사용하는 도구

| 도구 | 목적 | 실행 시점 |
|------|------|----------|
| **terraform fmt** | 코드 포맷팅 검사 | PR, Push |
| **terraform validate** | 문법 검증 | PR, Push |
| **TFLint** | 모범 사례 검사 | PR, Push |
| **TFSec** | 보안 취약점 스캔 | PR, Push |
| **Checkov** | 보안 및 컴플라이언스 검사 | PR, Push |
| **Terraform Docs** | 문서화 확인 | PR, Push |

### 자동화 흐름

```
개발자 코드 작성
    ↓
git push / PR 생성
    ↓
GitHub Actions 트리거
    ↓
    ├─→ Terraform Validate (문법 검사)
    ├─→ TFLint (모범 사례 검사)
    ├─→ TFSec (보안 스캔)
    ├─→ Checkov (컴플라이언스 검사)
    └─→ Terraform Docs (문서 확인)
    ↓
모든 테스트 통과 시 PR 승인 가능
```

---

## 테스트 도구 소개

### 1. Terraform Validate 🔍

**목적**: Terraform 코드 문법 검증

**검사 항목**:
- ✅ HCL 문법 오류
- ✅ 리소스 참조 오류
- ✅ 변수 타입 불일치
- ✅ 모듈 인자 누락

**예시 에러**:
```hcl
# 잘못된 코드
resource "aws_s3_bucket" "example" {
  bucket = var.bucket_name
  acl    = "private"
  # 에러: 'acl' 인자는 더 이상 사용되지 않음
}

# 올바른 코드
resource "aws_s3_bucket" "example" {
  bucket = var.bucket_name
}

resource "aws_s3_bucket_acl" "example" {
  bucket = aws_s3_bucket.example.id
  acl    = "private"
}
```

---

### 2. TFLint 📐

**목적**: Terraform 모범 사례 및 AWS 규칙 검사

**검사 항목**:
- ✅ 명명 규칙 (snake_case)
- ✅ 사용되지 않는 변수/선언
- ✅ 더 이상 사용되지 않는 문법
- ✅ AWS 리소스 타입 유효성
- ✅ 주석 구문 표준화

**예시 에러**:
```hcl
# 잘못된 코드 (camelCase 사용)
variable "bucketName" {
  type = string
}

# TFLint 에러:
# variable name should be snake_case

# 올바른 코드
variable "bucket_name" {
  type = string
}
```

**설정 파일**: `terraform/.tflint.hcl`

```hcl
plugin "aws" {
  enabled = true
  version = "0.30.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

rule "terraform_naming_convention" {
  enabled = true
  variable {
    format = "snake_case"
  }
}
```

---

### 3. TFSec 🔒

**목적**: Terraform 코드 보안 취약점 스캔

**검사 항목**:
- ✅ S3 버킷 Public 접근
- ✅ 암호화 미사용
- ✅ 보안 그룹 과도한 권한
- ✅ IAM 정책 와일드카드
- ✅ RDS Public 노출
- ✅ Lambda 환경 변수 평문

**예시 경고**:
```hcl
# 위험한 코드
resource "aws_s3_bucket" "example" {
  bucket = "my-bucket"
}

# TFSec 경고:
# aws-s3-enable-bucket-encryption
# S3 버킷에 암호화가 활성화되지 않음

# 안전한 코드
resource "aws_s3_bucket" "example" {
  bucket = "my-bucket"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "example" {
  bucket = aws_s3_bucket.example.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
```

**설정 파일**: `terraform/.tfsec.yml`

```yaml
minimum_severity: MEDIUM

exclude:
  # 개발 환경에서는 일부 체크 제외
  - aws-s3-enable-bucket-logging  # 비용 절감
  - aws-ec2-require-vpc-flow-logs-for-all-vpcs  # 개발 환경
```

---

### 4. Checkov ✔️

**목적**: 보안 및 컴플라이언스 검사 (가장 포괄적)

**검사 항목**:
- ✅ 600+ 보안 체크
- ✅ CIS Benchmark 준수
- ✅ GDPR/HIPAA 컴플라이언스
- ✅ 비밀 정보 노출 (API 키, 비밀번호)
- ✅ 네트워크 보안
- ✅ IAM 최소 권한 원칙

**예시 경고**:
```hcl
# 위험한 코드
resource "aws_security_group" "example" {
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # 전 세계 SSH 허용!
  }
}

# Checkov 경고:
# CKV_AWS_24: Ensure no security groups allow ingress from 0.0.0.0/0 to port 22

# 안전한 코드
resource "aws_security_group" "example" {
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]  # VPC 내부만 허용
  }
}
```

**설정 파일**: `terraform/.checkov.yml`

```yaml
framework:
  - terraform
  - secrets

skip-check:
  - CKV_AWS_18  # S3 액세스 로깅 - 비용 절감
  - CKV_AWS_50  # Lambda X-Ray - 선택적 활성화

soft-fail: true  # 경고만 표시, 빌드 실패 안 함
```

---

## GitHub Actions 자동화

### Workflow 파일

**파일**: `.github/workflows/terraform-tests.yml`

### 트리거 조건

1. **Pull Request**: `terraform/` 폴더 변경 시
2. **Push**: `main`, `develop` 브랜치에 Push 시
3. **수동 실행**: GitHub Actions 탭에서 "Run workflow"

### 실행 Job

#### 1. Terraform Validate (13개 레이어 병렬)
```
✅ bootstrap-oregon
✅ layers/01-network
✅ layers/02-security
... (모든 레이어)
```

#### 2. TFLint (13개 레이어 병렬)
```
✅ 명명 규칙 검사
✅ 사용되지 않는 선언 검사
✅ AWS 리소스 타입 검사
```

#### 3. TFSec (전체 프로젝트 스캔)
```
✅ 보안 취약점 스캔
✅ SARIF 결과를 GitHub Security 탭에 업로드
```

#### 4. Checkov (전체 프로젝트 스캔)
```
✅ 600+ 보안 체크
✅ 비밀 정보 노출 검사
✅ SARIF 결과 업로드
```

#### 5. Terraform Docs (문서화 확인)
```
✅ README.md 존재 확인
✅ main.tf 존재 확인
```

#### 6. Test Summary (결과 요약)
```
모든 테스트 결과 취합 및 요약
```

---

### GitHub Security 탭 연동

TFSec 및 Checkov 결과는 **GitHub Security 탭**에 자동으로 업로드됩니다.

```
GitHub Repository → Security → Code scanning alerts
    ↓
TFSec 및 Checkov가 발견한 보안 이슈 표시
    ↓
심각도별 필터링 (Critical, High, Medium, Low)
    ↓
각 이슈 클릭 → 코드 위치 및 해결 방법 확인
```

---

## 로컬에서 테스트 실행

### 사전 요구사항

```bash
# 1. Terraform 설치
terraform version
# Terraform v1.12.0

# 2. TFLint 설치
curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash
tflint --version
# TFLint version 0.50.0

# 3. TFSec 설치
brew install tfsec  # macOS
# 또는
curl -s https://raw.githubusercontent.com/aquasecurity/tfsec/master/scripts/install_linux.sh | bash
tfsec --version
# v1.28.0

# 4. Checkov 설치
pip install checkov
checkov --version
# 3.2.0
```

---

### 전체 테스트 실행

#### 1. Terraform Format 검사
```bash
cd terraform
terraform fmt -check -recursive

# 문제 발견 시 자동 수정:
terraform fmt -recursive
```

#### 2. Terraform Validate (모든 레이어)
```bash
# 스크립트로 모든 레이어 검사
for layer in bootstrap-oregon layers/*/; do
  echo "Validating $layer..."
  (cd "$layer" && terraform init -backend=false && terraform validate)
done
```

#### 3. TFLint 실행
```bash
# 전체 프로젝트 스캔
cd terraform
tflint --recursive

# 특정 레이어만 스캔
cd terraform/layers/01-network
tflint
```

#### 4. TFSec 실행
```bash
# 전체 프로젝트 스캔
cd terraform
tfsec .

# 특정 심각도 이상만 표시
tfsec . --minimum-severity MEDIUM

# 특정 레이어만 스캔
tfsec ./layers/01-network
```

#### 5. Checkov 실행
```bash
# 전체 프로젝트 스캔
cd terraform
checkov --directory . --framework terraform

# 간결한 출력
checkov --directory . --framework terraform --compact --quiet

# 특정 레이어만 스캔
checkov --directory ./layers/01-network --framework terraform
```

---

### 빠른 테스트 스크립트

프로젝트 루트에 `scripts/test-terraform.sh` 생성:

```bash
#!/bin/bash
set -e

echo "🧪 Starting Terraform Tests..."

# 1. Format Check
echo "📋 Checking Terraform format..."
terraform -chdir=terraform fmt -check -recursive

# 2. Validate
echo "✅ Validating Terraform code..."
for layer in terraform/bootstrap-oregon terraform/layers/*/; do
  echo "  → $(basename $layer)"
  (cd "$layer" && terraform init -backend=false > /dev/null && terraform validate > /dev/null)
done

# 3. TFLint
echo "📐 Running TFLint..."
cd terraform && tflint --recursive

# 4. TFSec
echo "🔒 Running TFSec..."
tfsec terraform --minimum-severity MEDIUM

# 5. Checkov
echo "✔️  Running Checkov..."
checkov --directory terraform --framework terraform --compact --quiet

echo "✅ All tests passed!"
```

**실행**:
```bash
chmod +x scripts/test-terraform.sh
./scripts/test-terraform.sh
```

---

## 테스트 규칙 커스터마이징

### TFLint 규칙 비활성화

**파일**: `terraform/.tflint.hcl`

```hcl
# 특정 규칙 비활성화
rule "terraform_unused_declarations" {
  enabled = false  # 사용되지 않는 선언 허용
}

# 명명 규칙 완화
rule "terraform_naming_convention" {
  enabled = true
  
  # 모듈명은 자유롭게
  module {
    format = "none"
  }
}
```

---

### TFSec 경고 억제

#### 방법 1: 설정 파일에서 제외

**파일**: `terraform/.tfsec.yml`

```yaml
exclude:
  - aws-s3-enable-bucket-logging
  - aws-ec2-require-vpc-flow-logs-for-all-vpcs
```

#### 방법 2: 코드에 주석으로 억제

```hcl
# tfsec:ignore:aws-s3-enable-bucket-encryption
resource "aws_s3_bucket" "example" {
  bucket = "my-bucket"
  # 이유: 개발 환경이므로 암호화 불필요
}
```

---

### Checkov 경고 억제

#### 방법 1: 설정 파일에서 제외

**파일**: `terraform/.checkov.yml`

```yaml
skip-check:
  - CKV_AWS_18  # S3 버킷 로깅
  - CKV_AWS_50  # Lambda X-Ray
```

#### 방법 2: 코드에 주석으로 억제

```hcl
# checkov:skip=CKV_AWS_18:개발 환경이므로 로깅 불필요
resource "aws_s3_bucket" "example" {
  bucket = "my-bucket"
}
```

---

## PR에서 테스트 결과 확인

### 1. Checks 탭 확인

```
Pull Request → Checks 탭
    ↓
Terraform Tests 워크플로우
    ↓
    ├─ Terraform Validate (13 jobs)
    ├─ TFLint (13 jobs)
    ├─ TFSec
    ├─ Checkov
    └─ Terraform Docs (13 jobs)
```

### 2. 테스트 실패 시

```
❌ TFLint failed
    ↓
로그 확인
    ↓
terraform/layers/01-network/main.tf:10:1
    variable "vpcCidr" should be "vpc_cidr" (snake_case)
    ↓
코드 수정 후 재Push
```

### 3. 보안 이슈 발견 시

```
⚠️ TFSec found security issues
    ↓
GitHub Security 탭 확인
    ↓
aws-s3-enable-bucket-encryption
    S3 버킷 암호화 미설정
    ↓
수정 또는 억제 주석 추가
```

---

## 문제 해결

### 문제 1: TFLint 플러그인 다운로드 실패
```
Error: Failed to download plugin
```

**해결**:
```bash
# 플러그인 수동 초기화
cd terraform/layers/01-network
tflint --init

# 캐시 삭제 후 재시도
rm -rf ~/.tflint.d/plugins
tflint --init
```

---

### 문제 2: Checkov 메모리 부족
```
MemoryError: Unable to allocate memory
```

**해결**:
```bash
# 디렉토리별로 분리 실행
checkov --directory terraform/layers/01-network
checkov --directory terraform/layers/02-security
# ... 각 레이어별로

# 또는 병렬 처리 비활성화
checkov --directory terraform --no-parallel
```

---

### 문제 3: TFSec False Positive
```
TFSec가 잘못된 경고를 표시함
```

**해결**:
```hcl
# 특정 리소스에만 억제 주석 추가
# tfsec:ignore:aws-s3-enable-bucket-encryption Reason: 개발 환경
resource "aws_s3_bucket" "dev_only" {
  bucket = "dev-bucket"
}
```

---

### 문제 4: GitHub Actions 권한 에러
```
Error: Resource not accessible by integration
```

**해결**:
```yaml
# .github/workflows/terraform-tests.yml

permissions:
  contents: read
  security-events: write  # SARIF 업로드 권한 추가
  pull-requests: write    # PR 코멘트 권한 추가
```

---

## 베스트 프랙티스

### 1. 로컬에서 먼저 테스트 ⚡
```bash
# Push 전에 로컬 테스트 실행
./scripts/test-terraform.sh

# 문제 해결 후 Push
git add .
git commit -m "fix: terraform formatting"
git push
```

### 2. Pre-commit Hook 사용 🪝

`.git/hooks/pre-commit` 생성:
```bash
#!/bin/bash
echo "Running Terraform tests..."
terraform -chdir=terraform fmt -check -recursive || {
  echo "❌ Terraform format check failed. Run 'terraform fmt -recursive'"
  exit 1
}
echo "✅ Tests passed!"
```

```bash
chmod +x .git/hooks/pre-commit
```

### 3. 억제 주석에 이유 명시 📝
```hcl
# ❌ 나쁜 예
# tfsec:ignore:aws-s3-enable-bucket-encryption
resource "aws_s3_bucket" "example" {
  bucket = "my-bucket"
}

# ✅ 좋은 예
# tfsec:ignore:aws-s3-enable-bucket-encryption Reason: 개발 환경이며, 중요 데이터 미포함
resource "aws_s3_bucket" "example" {
  bucket = "my-bucket"
}
```

### 4. 점진적 개선 🎯
```
1단계: terraform validate 통과
2단계: terraform fmt 정리
3단계: TFLint 경고 수정
4단계: TFSec Critical/High 이슈 수정
5단계: Checkov High 이슈 수정
```

---

## 요약

### 테스트 도구 비교

| 도구 | 속도 | 검사 범위 | 엄격함 | 추천 |
|------|------|----------|--------|------|
| **terraform validate** | ⚡⚡⚡ | 문법만 | 필수 | ✅ 필수 |
| **terraform fmt** | ⚡⚡⚡ | 포맷 | 필수 | ✅ 필수 |
| **TFLint** | ⚡⚡ | 모범 사례 | 보통 | ✅ 권장 |
| **TFSec** | ⚡⚡ | 보안 | 높음 | ✅ 권장 |
| **Checkov** | ⚡ | 보안+컴플라이언스 | 매우 높음 | ⚠️ 선택 |

### 자동화 흐름
```
코드 작성 → 로컬 테스트 → Push → GitHub Actions → 통과 → PR 승인
```

### 설정 파일
- `.github/workflows/terraform-tests.yml` - GitHub Actions
- `terraform/.tflint.hcl` - TFLint 설정
- `terraform/.tfsec.yml` - TFSec 설정
- `terraform/.checkov.yml` - Checkov 설정

### 테스트 실행 명령어
```bash
# 로컬 전체 테스트
./scripts/test-terraform.sh

# 개별 도구 실행
terraform fmt -check -recursive
tflint --recursive
tfsec terraform
checkov --directory terraform
```

---

**작성일**: 2025-11-09  
**작성자**: 황영현  
**버전**: 1.0
