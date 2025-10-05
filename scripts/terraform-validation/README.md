# Terraform 인프라 검증 스크립트

이 폴더는 Terraform으로 구축된 AWS 인프라의 검증 및 테스트를 위한 스크립트들을 포함합니다.

## 📁 스크립트 목록

### 🔍 `terraform-validation.sh`
**용도:** 전체 Terraform 인프라 검증 및 테스트
- Terraform 코드 품질 검증 (fmt, validate, tfsec, checkov)
- 레이어별 인프라 상태 확인
- 리소스 연결성 테스트
- 보안 및 컴플라이언스 검사

### 🌐 `validate-routing-gateways.sh`
**용도:** 라우팅 테이블 및 게이트웨이 검증 (완전 버전)
- VPC, Subnet, Route Table 구성 확인
- Internet Gateway, NAT Gateway 연결성 테스트
- 라우팅 규칙 및 경로 추적 시뮬레이션
- IPv6 라우팅 설정 검증
- AWS Well-Architected Framework 준수 확인

### 🌐 `validate-routing-gateways-simple.sh`
**용도:** 라우팅 테이블 및 게이트웨이 검증 (간단 버전)
- 의존성 최소화 (terraform, aws cli, jq 불필요)
- 모의 테스트 모드로 검증 로직 확인
- 네트워크 아키텍처 설계 검증

### 🔒 `security-validation.sh`
**용도:** Security 레이어 검증
- Security Groups 규칙 검증
- IAM 역할 및 정책 확인
- VPC 엔드포인트 연결성 테스트
- 보안 설정 컴플라이언스 검사

## 🚀 사용법

### 전체 인프라 검증
```bash
# 모든 레이어 검증
./scripts/terraform-validation/terraform-validation.sh

# 특정 레이어만 검증
./scripts/terraform-validation/terraform-validation.sh network
./scripts/terraform-validation/terraform-validation.sh security
./scripts/terraform-validation/terraform-validation.sh database
./scripts/terraform-validation/terraform-validation.sh application
```

### 개별 레이어 검증
```bash
# 라우팅 테이블 및 게이트웨이 검증 (완전 버전)
./scripts/terraform-validation/validate-routing-gateways.sh
./scripts/terraform-validation/validate-routing-gateways.sh --mock --verbose

# 라우팅 테이블 및 게이트웨이 검증 (간단 버전)
./scripts/terraform-validation/validate-routing-gateways-simple.sh
./scripts/terraform-validation/validate-routing-gateways-simple.sh --verbose

# Security 레이어 검증
./scripts/terraform-validation/security-validation.sh
```

## 📋 검증 항목

### 코드 품질 검증
- **terraform fmt**: 코드 포맷팅 표준화
- **terraform validate**: 구문 및 설정 검증
- **tfsec**: Terraform 보안 정적 분석
- **checkov**: 인프라 보안 및 컴플라이언스 검사

### 인프라 상태 검증
- **리소스 존재 확인**: 생성된 리소스 상태 점검
- **연결성 테스트**: 네트워크 및 서비스 간 연결 확인
- **보안 설정 검증**: 최소 권한 원칙 및 암호화 설정 확인

## 🔧 필수 도구

검증 스크립트 실행을 위해 다음 도구들이 설치되어 있어야 합니다:

```bash
# AWS CLI
aws --version

# Terraform
terraform --version

# 보안 검증 도구
tfsec --version
checkov --version

# 네트워크 도구
dig --version
nslookup --version
```

## 📊 검증 결과

각 스크립트는 다음과 같은 형태로 결과를 출력합니다:

```
✅ PASS: VPC 구성 확인
✅ PASS: Subnet 라우팅 테이블 검증
❌ FAIL: Security Group 규칙 검증
⚠️  WARN: 권장 설정 누락

=== 검증 요약 ===
총 검사 항목: 15
통과: 12
실패: 2
경고: 1
```

## 🚨 문제 해결

검증 실패 시 다음 단계를 따르세요:

1. **에러 로그 확인**: 스크립트 출력에서 구체적인 오류 메시지 확인
2. **Terraform 상태 확인**: `terraform plan`으로 인프라 상태 점검
3. **리소스 재생성**: 필요시 `terraform apply`로 리소스 재생성
4. **재검증**: 문제 해결 후 스크립트 재실행

## 📝 로그 및 보고서

검증 결과는 다음 위치에 저장됩니다:
- **로그 파일**: `logs/validation-YYYYMMDD-HHMMSS.log`
- **보고서**: `reports/infrastructure-validation-report.html`