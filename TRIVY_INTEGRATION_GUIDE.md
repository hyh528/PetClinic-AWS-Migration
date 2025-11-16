# 🔒 Trivy Integration Guide

## 📋 개요

Trivy를 Terraform Testing 워크플로우에 추가하여 추가적인 보안 스캔 레이어를 제공합니다.

### Trivy란?

**Trivy**는 Aqua Security에서 만든 종합 보안 스캐너로:
- **IaC (Infrastructure as Code)** 스캔
- **컨테이너 이미지** 취약점 스캔
- **파일시스템** 스캔
- **Git 레포지토리** 스캔
- **Kubernetes** 매니페스트 스캔
- **하드코딩된 시크릿** 감지

---

## 🆚 TFSec/Checkov와의 차이점

| 특징 | TFSec | Checkov | Trivy |
|------|-------|---------|-------|
| **주 목적** | Terraform 보안 | 멀티 IaC 컴플라이언스 | **종합 취약점 스캔** |
| **IaC 지원** | Terraform만 | 다중 (TF, CFN, K8s) | **다중 + 컨테이너** |
| **취약점 DB** | 내장 규칙 | 600+ 체크 | **CVE, NVD 연동** |
| **컨테이너 스캔** | ❌ | ❌ | **✅** |
| **시크릿 감지** | 제한적 | ✅ | **✅ (강력)** |
| **SBOM 생성** | ❌ | ❌ | **✅** |
| **속도** | 빠름 | 느림 | **중간** |

**핵심 차이**:
- TFSec/Checkov: Terraform 설정 오류 감지
- Trivy: **CVE 취약점 + 설정 오류 + 시크릿 감지**

---

## 🎯 Trivy가 추가로 감지하는 것들

### 1. CVE 기반 취약점

```terraform
# Terraform 모듈에서 사용하는 provider 버전의 취약점
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "3.50.0"  # CVE-2021-XXXXX 취약점 존재
    }
  }
}

# Trivy 감지:
# CVE-2021-XXXXX (HIGH)
# Provider: hashicorp/aws 3.50.0
# Fixed in: 3.51.0
# Recommendation: Upgrade to 3.51.0+
```

### 2. 하드코딩된 시크릿

```terraform
# 실수로 커밋된 AWS 자격증명
provider "aws" {
  access_key = "AKIA..." # 🚨 Hardcoded AWS Access Key!
  secret_key = "xxx..."  # 🚨 Hardcoded AWS Secret Key!
}

# Trivy 감지:
# SECRET: AWS Access Key detected
# File: provider.tf:3
# Severity: CRITICAL
# Recommendation: Use environment variables or AWS profiles
```

```terraform
# API 키 하드코딩
resource "aws_ssm_parameter" "api_key" {
  value = "sk-1234567890abcdef..."  # 🚨 API Key detected!
}

# Trivy 감지:
# SECRET: Generic API Key detected
# Pattern: sk-[0-9a-f]{32}
```

### 3. 알려진 취약한 설정 패턴

```terraform
# 취약한 암호화 알고리즘
resource "aws_s3_bucket_server_side_encryption_configuration" "example" {
  bucket = aws_s3_bucket.example.id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES128"  # 🚨 Weak encryption!
    }
  }
}

# Trivy 감지:
# AVD-AWS-0088: S3 bucket uses weak encryption
# Severity: MEDIUM
# Recommendation: Use AES256 or aws:kms
```

### 4. 라이센스 문제

```terraform
# 특정 라이센스가 있는 모듈 사용
module "third_party" {
  source = "github.com/company/module"
  # 이 모듈이 AGPL 라이센스일 경우
}

# Trivy 감지:
# LICENSE: AGPL-3.0 detected
# Severity: LOW
# Note: Ensure compliance with license terms
```

---

## 📦 추가된 워크플로우 구성

### GitHub Actions Job

```yaml
trivy:
  name: Trivy Security Scan
  runs-on: ubuntu-latest
  permissions:
    contents: read
    security-events: write
  steps:
    # 1. SARIF 형식으로 스캔 (GitHub Security 탭용)
    - name: Run Trivy IaC scan
      uses: aquasecurity/trivy-action@master
      with:
        scan-type: 'config'
        scan-ref: 'terraform/'
        format: 'sarif'
        output: 'trivy-results.sarif'
        severity: 'CRITICAL,HIGH,MEDIUM'
        exit-code: '0'

    - name: Upload Trivy SARIF
      if: always()
      uses: github/codeql-action/upload-sarif@v3
      with:
        sarif_file: trivy-results.sarif
        category: trivy

    # 2. Table 형식으로 스캔 (Actions 로그용)
    - name: Run Trivy IaC scan (table output)
      uses: aquasecurity/trivy-action@master
      with:
        scan-type: 'config'
        scan-ref: 'terraform/'
        format: 'table'
        severity: 'CRITICAL,HIGH,MEDIUM'
        exit-code: '0'
```

### 설정 파라미터 설명

| 파라미터 | 값 | 설명 |
|---------|---|------|
| **scan-type** | `config` | IaC 파일 스캔 (컨테이너가 아님) |
| **scan-ref** | `terraform/` | 스캔할 디렉토리 |
| **format** | `sarif` / `table` | 출력 형식 |
| **severity** | `CRITICAL,HIGH,MEDIUM` | 스캔할 심각도 레벨 |
| **exit-code** | `0` | 취약점 발견해도 빌드 통과 |

---

## 🔧 설정 파일

### .trivyignore

특정 취약점을 무시하는 파일:

```bash
# Trivy Ignore File
# 형식: AVD-{PROVIDER}-{NUMBER}

# S3 버킷 로깅 (비용 절감)
AVD-AWS-0086

# ECS 태스크 권한 (개발 환경)
AVD-AWS-0132

# CVE 무시 (False Positive)
CVE-2021-12345

# 특정 파일 제외
# layers/11-frontend/main.tf
```

**무시 규칙 형식**:
- `AVD-AWS-0086`: Trivy의 AWS 체크 ID
- `CVE-2021-12345`: 특정 CVE
- `# 경로`: 특정 파일의 모든 이슈 무시

### trivy.yaml

Trivy 설정 파일:

```yaml
# 스캔 설정
scan:
  file-patterns:
    - "*.tf"
    - "*.tfvars"
  
  security-checks:
    - config      # IaC 설정 스캔
    - secret      # 시크릿 감지

# 심각도
severity:
  - CRITICAL
  - HIGH
  - MEDIUM

# 캐시
cache:
  backend: fs
  ttl: 24h

# 타임아웃
timeout: 5m

# 종료 코드 (CI/CD에서 계속 진행)
exit-code: 0
```

---

## 🔍 스캔 결과 예시

### Table 출력 (Actions 로그)

```
terraform/layers/02-security/main.tf (terraform)
=================================================

Tests: 15 (SUCCESSES: 10, FAILURES: 5, EXCEPTIONS: 0)
Failures: 5 (CRITICAL: 1, HIGH: 2, MEDIUM: 2, LOW: 0, UNKNOWN: 0)

CRITICAL: Security group rule allows ingress from public internet
═══════════════════════════════════════════════════════════════
Security group rules should not allow ingress from 0.0.0.0/0

See https://avd.aquasec.com/misconfig/avd-aws-0107
────────────────────────────────────────────────────────────────
 main.tf:45-50
────────────────────────────────────────────────────────────────
  45 ┌   ingress {
  46 │     from_port   = 22
  47 │     to_port     = 22
  48 │     protocol    = "tcp"
  49 └     cidr_blocks = ["0.0.0.0/0"]  # 문제!
  50     }
────────────────────────────────────────────────────────────────


HIGH: S3 bucket does not have encryption enabled
═══════════════════════════════════════════════
S3 buckets should be encrypted

See https://avd.aquasec.com/misconfig/avd-aws-0088
────────────────────────────────────────────────────────────────
 main.tf:120-125
────────────────────────────────────────────────────────────────
```

### SARIF 출력 (GitHub Security 탭)

GitHub Security 탭에서:
- 파일별로 취약점 표시
- 라인 번호로 점프
- 수정 방법 제안
- 심각도별 필터링
- 시간 경과 추이 그래프

---

## 🎨 TFSec/Checkov와의 통합

### 중복 체크 처리

동일한 이슈를 여러 도구가 감지할 수 있습니다:

```
Issue: S3 bucket not encrypted

TFSec:   aws-s3-enable-bucket-encryption
Checkov: CKV_AWS_19
Trivy:   AVD-AWS-0088
```

**해결 방법**:
1. **한 도구에서만 체크**: 중복 제거
2. **교차 검증**: 여러 도구가 동의하는 이슈는 더 중요

**권장 구성**:
```yaml
# TFSec: Terraform 특화 체크 (빠름)
tfsec:
  minimum_severity: HIGH

# Checkov: 컴플라이언스 체크
checkov:
  frameworks: [CIS, PCI-DSS]
  
# Trivy: CVE + 시크릿 감지
trivy:
  severity: CRITICAL,HIGH
  secret-scanning: enabled
```

### 역할 분담

| 도구 | 주요 역할 | 보조 역할 |
|------|----------|----------|
| **TFSec** | Terraform 설정 오류 | - |
| **Checkov** | 컴플라이언스 검증 | IaC 오류 |
| **Trivy** | **CVE + 시크릿** | IaC 오류 |

---

## 📊 성능 영향

### 실행 시간 추가

| 도구 | 기존 시간 | 추가 시간 |
|------|----------|----------|
| terraform-validate | 30s | - |
| tflint | 45s | - |
| tfsec | 60s | - |
| checkov | 120s | - |
| **trivy** | - | **+45s** |
| **합계** | **3분** | **3분 45초** |

**최적화 방법**:
1. **캐싱**: Trivy DB 캐시 활용
2. **병렬 실행**: 다른 Job과 병렬로 실행 (이미 적용됨)
3. **심각도 제한**: CRITICAL, HIGH만 스캔

### 캐싱 설정

```yaml
- name: Cache Trivy DB
  uses: actions/cache@v3
  with:
    path: ~/.cache/trivy
    key: trivy-db-${{ github.run_id }}
    restore-keys: trivy-db-
```

---

## 🚀 사용 시나리오

### 1. PR 체크로 사용

```yaml
on:
  pull_request:
    paths:
      - 'terraform/**'
```

**효과**:
- 머지 전에 취약점 발견
- 시크릿 커밋 방지
- CVE 데이터베이스 최신 버전으로 체크

### 2. 정기 스캔

```yaml
on:
  schedule:
    - cron: '0 0 * * 0'  # 매주 일요일
```

**효과**:
- 새로 발견된 CVE 감지
- 취약점 DB 업데이트 후 재검사
- 보안 추세 모니터링

### 3. 컨테이너 이미지 스캔 (추가)

```yaml
- name: Build Docker image
  run: docker build -t myapp:latest .

- name: Run Trivy image scan
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: 'myapp:latest'
    format: 'sarif'
    output: 'trivy-image-results.sarif'
```

---

## 🔒 시크릿 감지 예시

### 감지 가능한 시크릿 타입

| 타입 | 패턴 예시 |
|------|----------|
| **AWS Access Key** | `AKIA[0-9A-Z]{16}` |
| **AWS Secret Key** | `[0-9a-zA-Z/+=]{40}` |
| **GitHub Token** | `ghp_[0-9a-zA-Z]{36}` |
| **Slack Token** | `xox[baprs]-[0-9]{10,12}-[0-9a-zA-Z]{24,32}` |
| **Generic API Key** | `api[_-]?key[_-]?=.{32,}` |
| **Private Key** | `-----BEGIN.*PRIVATE KEY-----` |
| **JWT Token** | `eyJ[A-Za-z0-9-_=]+\.[A-Za-z0-9-_=]+\.[A-Za-z0-9-_=]+` |

### False Positive 처리

```terraform
# 예제 코드에서 가짜 키 사용
variable "example_api_key" {
  description = "Example API key (not real)"
  default     = "sk-example1234567890abcdef"  # trivy:ignore secret
}
```

**무시 주석**:
- `# trivy:ignore secret`: 해당 줄의 시크릿 감지 무시
- `# trivy:ignore AVD-AWS-0086`: 특정 체크 무시

---

## 📈 결과 확인

### 1. GitHub Actions 로그

**Table 형식으로 상세 정보 표시**:
- 취약점 목록
- 파일 위치
- 라인 번호
- 수정 권장사항

### 2. GitHub Security 탭

**SARIF 업로드로 통합 뷰 제공**:
- TFSec 결과
- Checkov 결과
- **Trivy 결과** (추가됨)

**필터링**:
- 심각도별
- 도구별
- 파일별
- 시간별

### 3. Test Summary

```markdown
## Terraform Test Results

| Test | Status |
|------|--------|
| Format & Validate | ✅ success |
| TFLint | ✅ success |
| TFSec | ✅ success |
| Checkov | ✅ success |
| **Trivy** | **✅ success** |
| Documentation | ✅ success |
```

---

## 🛠️ 문제 해결

### 1. 복잡한 Terraform 파싱 오류

**증상**:
```
panic: inconsistent map element types
```

**원인**: 매우 복잡한 for_each 또는 dynamic 블록

**해결**:
```yaml
# 특정 파일 제외
- name: Run Trivy
  with:
    skip-dirs: 'terraform/layers/complex-layer'
```

또는:
```bash
# .trivyignore
terraform/layers/complex-layer/**
```

### 2. DB 다운로드 실패

**증상**:
```
failed to download vulnerability DB
```

**해결**:
```yaml
- name: Run Trivy
  uses: aquasecurity/trivy-action@master
  with:
    download-db-only: true  # DB만 먼저 다운로드
    
- name: Run actual scan
  uses: aquasecurity/trivy-action@master
  with:
    skip-db-update: true    # 이미 다운로드된 DB 사용
```

### 3. 너무 많은 경고

**해결 방법 1**: 심각도 제한
```yaml
severity: 'CRITICAL,HIGH'  # MEDIUM 제외
```

**해결 방법 2**: 특정 타입만 스캔
```yaml
security-checks:
  - secret  # 시크릿만 감지, config는 TFSec/Checkov에 맡김
```

---

## 📚 추가 기능

### SBOM (Software Bill of Materials) 생성

```yaml
- name: Generate SBOM
  uses: aquasecurity/trivy-action@master
  with:
    scan-type: 'fs'
    scan-ref: 'terraform/'
    format: 'cyclonedx'
    output: 'sbom.json'
```

**용도**:
- 사용된 모든 의존성 추적
- 라이센스 컴플라이언스
- 공급망 보안

### 커스텀 정책

```rego
# custom-policy.rego
package user.terraform.aws

deny[msg] {
  resource := input.aws_instance[_]
  not resource.monitoring
  msg := "EC2 instance must have detailed monitoring enabled"
}
```

```yaml
- name: Run Trivy with custom policy
  uses: aquasecurity/trivy-action@master
  with:
    scan-type: 'config'
    scan-ref: 'terraform/'
    policy: 'custom-policy.rego'
```

---

## 🎯 권장 사항

### 1. 단계적 도입

**Phase 1** (초기):
```yaml
severity: 'CRITICAL'
exit-code: '0'  # 경고만
```

**Phase 2** (안정화):
```yaml
severity: 'CRITICAL,HIGH'
exit-code: '0'
```

**Phase 3** (성숙):
```yaml
severity: 'CRITICAL,HIGH,MEDIUM'
exit-code: '1'  # 취약점 발견 시 빌드 실패
```

### 2. 역할 분담

- **TFSec**: Terraform 설정 오류 (빠른 피드백)
- **Checkov**: 컴플라이언스 검증 (상세 체크)
- **Trivy**: CVE + 시크릿 감지 (보안 중심)

### 3. 정기 리뷰

```yaml
# 매주 전체 스캔
on:
  schedule:
    - cron: '0 0 * * 0'

# 최신 취약점 DB로 재검사
- name: Run Trivy
  with:
    skip-db-update: false  # 항상 최신 DB 사용
```

---

## 📖 참고 자료

### 공식 문서
- **Trivy**: https://aquasecurity.github.io/trivy/
- **Trivy Checks**: https://avd.aquasec.com/misconfig/terraform/

### GitHub Action
- **trivy-action**: https://github.com/aquasecurity/trivy-action

### 프로젝트 파일
- `.github/workflows/terraform-tests.yml` - 워크플로우
- `terraform/.trivyignore` - 무시 규칙
- `terraform/trivy.yaml` - 설정 파일

---

## ✨ 요약

**Trivy 추가로 얻는 이점**:

1. ✅ **CVE 취약점 감지**: 알려진 보안 취약점
2. ✅ **시크릿 감지**: 하드코딩된 자격증명
3. ✅ **다층 보안**: TFSec/Checkov 보완
4. ✅ **SBOM 생성**: 의존성 추적
5. ✅ **최신 취약점 DB**: 지속적 업데이트

**Trivy를 사용해야 하는 경우**:
- 컨테이너 이미지도 스캔해야 할 때
- CVE 데이터베이스 기반 검사 필요
- 시크릿 감지가 중요할 때
- 종합 보안 스캔 원할 때

**다른 도구로 충분한 경우**:
- Terraform만 사용
- 컴플라이언스가 주 목적
- 빠른 피드백이 중요

---

**Trivy로 한 단계 더 강력한 보안을 확보하세요!** 🔒🚀
