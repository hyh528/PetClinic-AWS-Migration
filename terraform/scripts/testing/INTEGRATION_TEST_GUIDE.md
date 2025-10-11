# Terraform 통합 테스트 가이드

## 개요

이 문서는 Terraform 레이어 아키텍처의 통합 테스트 실행 방법을 설명합니다. 통합 테스트는 다음 항목들을 검증합니다:

- 전체 레이어 순차 배포 테스트
- 상태 파일 분리 및 잠금 테스트  
- 롤백 시나리오 테스트
- 레이어 간 의존성 검증

## 사전 요구사항

### 필수 도구
- Terraform >= 1.8.0
- AWS CLI >= 2.0
- PowerShell 5.1+ (Windows) 또는 Bash 4.0+ (Linux/macOS)
- jq (JSON 처리용)

### AWS 설정
```bash
# AWS 프로필 설정 확인
aws configure list --profile petclinic-dev

# 자격 증명 테스트
aws sts get-caller-identity --profile petclinic-dev
```

### 환경 변수
```bash
# 필요시 설정
export AWS_PROFILE=petclinic-dev
export AWS_REGION=ap-northeast-2
```

## 테스트 실행 방법

### Windows (PowerShell)

#### 기본 통합 테스트 실행
```powershell
# 전체 통합 테스트 (배포 + 검증 + 정리)
.\terraform\scripts\integration-test.ps1

# 특정 환경에서 실행
.\terraform\scripts\integration-test.ps1 -Environment "dev"

# 정리 단계 건너뛰기 (리소스 유지)
.\terraform\scripts\integration-test.ps1 -SkipCleanup

# 롤백 테스트 포함
.\terraform\scripts\integration-test.ps1 -TestRollback

# 상태 잠금 테스트 포함
.\terraform\scripts\integration-test.ps1 -TestStateLocking
```

#### 특정 테스트 유형만 실행
```powershell
# 배포 테스트만
.\terraform\scripts\integration-test.ps1 -TestType "deploy"

# 상태 관리 테스트만
.\terraform\scripts\integration-test.ps1 -TestType "state"

# 롤백 테스트만
.\terraform\scripts\integration-test.ps1 -TestType "rollback"
```

### Linux/macOS (Bash)

#### 기본 통합 테스트 실행
```bash
# 전체 통합 테스트
./terraform/scripts/integration-test.sh

# 특정 환경에서 실행
./terraform/scripts/integration-test.sh --environment dev

# 정리 단계 건너뛰기
./terraform/scripts/integration-test.sh --skip-cleanup

# 롤백 테스트 포함
./terraform/scripts/integration-test.sh --test-rollback

# 상태 잠금 테스트 포함
./terraform/scripts/integration-test.sh --test-state-locking
```

#### 특정 테스트 유형만 실행
```bash
# 배포 테스트만
./terraform/scripts/integration-test.sh --test-type deploy

# 상태 관리 테스트만
./terraform/scripts/integration-test.sh --test-type state

# 롤백 테스트만
./terraform/scripts/integration-test.sh --test-type rollback
```

## 테스트 시나리오 상세

### 1. 순차 배포 테스트

**목적**: 모든 레이어가 올바른 순서로 배포되는지 검증

**과정**:
1. 레이어 의존성 확인
2. 각 레이어별 terraform init, plan, apply 실행
3. 배포된 리소스 검증
4. 상태 파일 생성 확인

**검증 항목**:
- 의존성 순서 준수
- 각 레이어의 성공적인 배포
- 상태 파일 생성 및 유효성
- AWS 리소스 실제 생성 확인

### 2. 상태 파일 분리 테스트

**목적**: 각 레이어가 독립적인 상태 파일을 사용하는지 검증

**과정**:
1. 각 레이어의 backend 설정 확인
2. 상태 파일 키의 고유성 검증
3. 원격 상태 저장소 접근 확인

**검증 항목**:
- 고유한 상태 파일 키 사용
- S3 backend 설정 정확성
- DynamoDB 잠금 테이블 설정

### 3. 상태 잠금 테스트

**목적**: 동시 실행 시 상태 잠금이 정상 작동하는지 검증

**과정**:
1. 첫 번째 terraform 작업 시작 (백그라운드)
2. 두 번째 terraform 작업 시작 (잠금 대기)
3. 잠금 메커니즘 작동 확인

**검증 항목**:
- DynamoDB 잠금 테이블 사용
- 동시 실행 차단
- 잠금 해제 후 정상 실행

### 4. 롤백 시나리오 테스트

**목적**: 배포 실패 시 롤백이 정상 작동하는지 검증

**과정**:
1. 현재 상태 백업
2. 테스트 변경사항 적용
3. 백업 상태로 롤백 실행
4. 롤백 결과 검증

**검증 항목**:
- 백업 계획 생성
- 롤백 실행 성공
- 원래 상태로 복원

## 테스트 결과 해석

### 성공 기준
- 모든 레이어 배포 성공 (100%)
- 상태 파일 분리 확인
- 의존성 순서 준수
- 오류 0개

### 경고 상황
- 일부 레이어 건너뜀 (디렉터리 없음)
- 상태 파일 검증 실패
- 리소스 정리 실패

### 실패 상황
- 레이어 배포 실패
- 의존성 오류
- 상태 잠금 실패
- 롤백 실패

## 테스트 결과 보고서

### 보고서 위치
```
integration-test-results/
├── integration-test-dev-20241211-143022.json
├── integration-test-dev-20241211-143022.html
└── terraform-logs/
    ├── 01-network-20241211-143022.log
    ├── 02-security-20241211-143022.log
    └── ...
```

### JSON 보고서 구조
```json
{
  "start_time": "2024-12-11T14:30:22+09:00",
  "end_time": "2024-12-11T14:45:15+09:00",
  "duration_minutes": 15,
  "environment": "dev",
  "test_type": "full",
  "total_layers": 10,
  "successful_layers": 10,
  "failed_layers": 0,
  "errors": 0,
  "warnings": 1,
  "test_results": {
    "01-network": {
      "status": "Success",
      "duration": 120,
      "resources": 15
    }
  }
}
```

## 문제 해결

### 일반적인 문제

#### 1. AWS 자격 증명 오류
```bash
# 해결 방법
aws configure --profile petclinic-dev
aws sts get-caller-identity --profile petclinic-dev
```

#### 2. Terraform 초기화 실패
```bash
# 해결 방법
cd terraform/envs/dev/01-network
rm -rf .terraform
terraform init -upgrade
```

#### 3. 상태 잠금 오류
```bash
# 해결 방법 (주의: 다른 작업이 실행 중이지 않은지 확인)
terraform force-unlock <LOCK_ID>
```

#### 4. 리소스 정리 실패
```bash
# 수동 정리
cd terraform/envs/dev/10-aws-native
terraform destroy -auto-approve
# 역순으로 모든 레이어 정리
```

### 로그 확인
```bash
# 상세 로그 확인
export TF_LOG=DEBUG
./terraform/scripts/integration-test.sh

# 특정 레이어 로그 확인
cd terraform/envs/dev/01-network
terraform plan -var-file=dev.tfvars
```

## CI/CD 통합

### GitHub Actions 예시
```yaml
name: Terraform Integration Test

on:
  pull_request:
    paths:
      - 'terraform/**'

jobs:
  integration-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ap-northeast-2
          
      - name: Run Integration Tests
        run: |
          chmod +x terraform/scripts/integration-test.sh
          ./terraform/scripts/integration-test.sh --environment dev --test-type deploy
```

## 모범 사례

### 테스트 실행 전
1. 현재 AWS 계정 확인
2. 기존 리소스 충돌 여부 확인
3. 충분한 AWS 권한 확인
4. 테스트 환경 격리 확인

### 테스트 실행 중
1. 로그 모니터링
2. AWS 콘솔에서 리소스 생성 확인
3. 비용 모니터링

### 테스트 실행 후
1. 테스트 결과 보고서 검토
2. 실패한 테스트 원인 분석
3. 필요시 수동 리소스 정리
4. 보고서 아카이브

## 추가 리소스

- [Terraform 베스트 프랙티스](../docs/TERRAFORM_BEST_PRACTICES.md)
- [AWS Well-Architected Framework](../docs/AWS_WELL_ARCHITECTED.md)
- [레이어 실행 순서](../docs/LAYER_EXECUTION_ORDER.md)
- [문제 해결 가이드](../docs/TROUBLESHOOTING.md)