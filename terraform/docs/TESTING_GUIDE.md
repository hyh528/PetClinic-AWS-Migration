# Terraform 테스트 자동화 가이드

## 개요

이 문서는 PetClinic AWS 마이그레이션 프로젝트의 Terraform 테스트 자동화 시스템 사용법을 설명합니다. 단위 테스트부터 통합 테스트까지 전체 테스트 파이프라인을 다룹니다.

## 테스트 아키텍처

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Static Tests  │    │   Unit Tests    │    │Integration Tests│
│                 │    │                 │    │                 │
│ • terraform fmt │    │ • Terratest     │    │ • Python Runner │
│ • terraform     │    │ • Go-based      │    │ • AWS API       │
│   validate      │    │ • Module-level  │    │ • End-to-end    │
│ • tflint        │    │ • Real AWS      │    │ • Multi-service │
│ • checkov       │    │   resources     │    │   validation    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
        │                       │                       │
        └───────────────────────┼───────────────────────┘
                                │
                    ┌─────────────────┐
                    │  GitHub Actions │
                    │   CI/CD Pipeline│
                    └─────────────────┘
```

## 테스트 유형

### 1. 정적 테스트 (Static Tests)
**실행 시점:** 모든 PR 및 푸시
**소요 시간:** 2-5분
**목적:** 코드 품질 및 보안 검증

```bash
# 로컬에서 실행
terraform fmt -check -recursive terraform/
terraform validate
tflint --recursive terraform/
# checkov는 GitHub Actions에서 자동 실행됨
```

### 2. 단위 테스트 (Unit Tests)
**실행 시점:** PR에서 변경된 모듈에 대해서만
**소요 시간:** 10-30분 (모듈당)
**목적:** 개별 모듈의 기능 검증

```bash
# 특정 모듈 테스트
cd terraform/modules/vpc/test
go test -v -timeout 30m

# 모든 모듈 테스트
.github/workflows/terraform-unit-tests.yml
```

### 3. 통합 테스트 (Integration Tests)
**실행 시점:** 배포 완료 후
**소요 시간:** 15-30분
**목적:** 전체 시스템 상호작용 검증

```bash
# Python 통합 테스트 실행
cd terraform/scripts
python3 integration_test_runner.py integration-test-enhanced.yaml dev
```

## 사용법

### PR 워크플로우

1. **PR 생성 시 자동 실행:**
   - 정적 테스트 (모든 변경사항)
   - 단위 테스트 (변경된 모듈만)

2. **테스트 결과 확인:**
   - GitHub Actions 탭에서 실행 상태 확인
   - PR 코멘트에서 테스트 결과 요약 확인

3. **테스트 실패 시:**
   - 실패 로그 확인
   - 코드 수정 후 다시 푸시
   - 테스트 자동 재실행

### 배포 워크플로우

1. **메인 브랜치 머지 후:**
   - 인프라 배포 자동 실행
   - 배포 완료 후 통합 테스트 자동 실행

2. **수동 배포:**
   ```bash
   # GitHub Actions에서 수동 실행
   # Repository → Actions → Full System Deployment
   ```

### 로컬 테스트 실행

#### 단위 테스트
```bash
# 1. 공통 테스트 모듈 설정
cd terraform/test/common
go mod tidy

# 2. 특정 모듈 테스트
cd terraform/modules/vpc/test
go mod tidy
go test -v -timeout 30m

# 3. 환경 변수 설정 (필요시)
export AWS_PROFILE=petclinic-dev
export AWS_REGION=ap-northeast-1
export TF_VAR_test_id="local-$(date +%s)"
```

#### 통합 테스트
```bash
# 1. Python 의존성 설치
pip install -r terraform/scripts/requirements.txt

# 2. AWS 자격 증명 설정
aws configure --profile petclinic-dev

# 3. 통합 테스트 실행
cd terraform/scripts
python3 integration_test_runner.py integration-test-enhanced.yaml dev --verbose

# 4. 특정 테스트 스위트만 실행
python3 integration_test_runner.py integration-test-enhanced.yaml dev --verbose
```

## 테스트 설정

### 환경 변수
```bash
# GitHub Actions에서 자동 설정되는 변수들
GITHUB_PR_NUMBER=123
TF_VAR_test_id="pr-123-vpc-456"
TF_VAR_environment="test"
AWS_REGION="ap-northeast-1"
```

### 테스트 태그
모든 테스트 리소스는 자동으로 다음 태그가 적용됩니다:
```hcl
tags = {
  Purpose     = "terratest"
  TestID      = "pr-123-vpc-456"
  Environment = "test"
  CreatedAt   = "2024-01-15T10:30:00Z"
  ManagedBy   = "terratest"
}
```

## 트러블슈팅

### 일반적인 문제

#### 1. 단위 테스트 타임아웃
```bash
# 증상: 테스트가 30분 후 타임아웃
# 해결: 리소스 생성 시간이 오래 걸리는 경우
go test -v -timeout 45m  # 타임아웃 연장
```

#### 2. AWS 권한 오류
```bash
# 증상: AccessDenied 오류
# 해결: IAM 권한 확인
aws sts get-caller-identity
aws iam get-user
```

#### 3. 리소스 정리 실패
```bash
# 수동 정리 방법
cd terraform/modules/vpc/test
terraform destroy -auto-approve -var="test_id=pr-123-vpc-456"

# 또는 AWS CLI로 태그 기반 정리
aws resourcegroupstaggingapi get-resources \
  --tag-filters Key=TestID,Values=pr-123-vpc-456
```

#### 4. 통합 테스트 실패
```bash
# 로그 확인
python3 integration_test_runner.py config.yaml dev --verbose

# 특정 테스트만 실행
# config.yaml에서 해당 테스트 스위트만 남기고 실행
```

### 디버깅 팁

#### 테스트 환경 보존
```go
// 실패 시 리소스 보존 (디버깅용)
config := common.NewTestConfig(t, "../")
config.PreserveOnFailure(t, true)  // 실패 시 7일간 보존
```

#### 상세 로그 활성화
```bash
# Go 테스트 상세 로그
go test -v -timeout 30m

# Python 통합 테스트 상세 로그
python3 integration_test_runner.py config.yaml dev --verbose
```

## 성능 최적화

### 병렬 실행
```go
// 단위 테스트 병렬 실행
func TestVpcModule(t *testing.T) {
    t.Parallel()  // 다른 테스트와 병렬 실행
    // ...
}
```

### 캐시 활용
GitHub Actions에서 Go 모듈 캐시 자동 활용:
```yaml
- name: Cache Go modules
  uses: actions/cache@v3
  with:
    path: |
      ~/.cache/go-build
      ~/go/pkg/mod
    key: ${{ runner.os }}-go-${{ hashFiles('**/go.sum') }}
```

### 리소스 최적화
```go
// 최소한의 리소스로 테스트
config.SetVariables(map[string]interface{}{
    "instance_class": "db.t3.micro",  // 최소 인스턴스
    "desired_count":  1,              // 최소 개수
})
```

## 모니터링

### 테스트 메트릭
- 성공률: GitHub Actions 대시보드에서 확인
- 실행 시간: 각 워크플로우 실행 로그에서 확인
- 비용: AWS Cost Explorer에서 `Purpose=terratest` 태그로 필터링

### 알림 설정
테스트 실패 시 자동 알림:
- GitHub Actions 실패 알림
- PR 코멘트 자동 업데이트
- Slack 알림 (선택사항)

## 베스트 프랙티스

### 테스트 작성 시
1. **격리된 환경 사용**: 각 테스트는 독립적인 리소스 사용
2. **자동 정리**: defer를 사용한 리소스 정리
3. **의미있는 테스트 이름**: 테스트 목적이 명확한 이름 사용
4. **적절한 타임아웃**: 리소스 생성 시간을 고려한 타임아웃 설정

### CI/CD 통합 시
1. **점진적 롤아웃**: 새로운 테스트는 단계적으로 추가
2. **실패 시 빠른 피드백**: 테스트 실패 시 즉시 알림
3. **비용 관리**: 테스트 리소스 자동 정리로 비용 최소화
4. **문서화**: 테스트 변경 시 문서 업데이트
