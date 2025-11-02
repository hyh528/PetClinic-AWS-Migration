# Terraform Tests

이 디렉토리는 PetClinic Terraform 인프라의 자동화된 테스트를 포함합니다.

## 📋 테스트 구조

```
test/
├── common/                 # 공통 테스트 헬퍼 및 유틸리티
│   ├── aws_helpers.go     # AWS 리소스 검증 헬퍼
│   ├── test_helper.go     # 테스트 설정 및 관리
│   └── go.mod             # 공통 모듈 의존성
├── network_test.go        # 네트워크 레이어 테스트
├── security_test.go       # 보안 레이어 테스트
├── database_test.go       # 데이터베이스 레이어 테스트 (예정)
├── application_test.go    # 애플리케이션 레이어 테스트 (예정)
├── go.mod                 # 테스트 모듈 의존성
├── Makefile              # 테스트 실행 자동화
└── README.md             # 이 파일
```

## 🚀 빠른 시작

### 1. 사전 요구사항

- Go 1.21+
- Terraform 1.8+
- AWS CLI 설정
- AWS 자격 증명 구성

### 2. 의존성 설치

```bash
cd terraform/test
make deps
```

### 3. 테스트 실행

```bash
# 모든 단위 테스트 실행 (빠름, AWS 리소스 생성 안함)
make test-unit

# 모든 테스트 실행 (단위 + 통합)
make test

# 특정 레이어 테스트
make test-network
make test-security
```

## 🧪 테스트 유형

### 단위 테스트 (Unit Tests)
- **목적**: Terraform 설정의 구문 및 논리 검증
- **특징**: 빠른 실행, AWS 리소스 생성 안함
- **실행**: `make test-unit` 또는 `go test -short`

```go
func TestNetworkLayer(t *testing.T) {
    t.Parallel()
    // Plan만 실행하여 설정 검증
}
```

### 통합 테스트 (Integration Tests)
- **목적**: 실제 AWS 리소스 생성 및 검증
- **특징**: 느린 실행, 실제 비용 발생 가능
- **실행**: `make test-integration`

```go
func TestNetworkLayerIntegration(t *testing.T) {
    if testing.Short() {
        t.Skip("Skipping integration test in short mode")
    }
    // 실제 리소스 생성 및 검증
}
```

## 📊 테스트 명령어

| 명령어 | 설명 | 실행 시간 | AWS 리소스 |
|--------|------|-----------|------------|
| `make test-unit` | 단위 테스트만 실행 | ~2분 | 생성 안함 |
| `make test-integration` | 통합 테스트만 실행 | ~15분 | 생성함 |
| `make test` | 모든 테스트 실행 | ~20분 | 생성함 |
| `make test-network` | 네트워크 레이어만 | ~5분 | 생성함 |
| `make test-security` | 보안 레이어만 | ~3분 | 생성함 |
| `make test-parallel` | 병렬 단위 테스트 | ~1분 | 생성 안함 |

## 🔧 테스트 설정

### 환경 변수

```bash
# AWS 설정
export AWS_REGION=ap-northeast-2
export AWS_PROFILE=petclinic-dev

# 테스트 설정
export TF_VAR_environment=test
export GITHUB_PR_NUMBER=123  # CI에서 자동 설정
```

### 테스트 설정 파일

각 테스트는 `common.TestConfig`를 사용하여 설정됩니다:

```go
config := common.NewTestConfig(t, "../layers/01-network").
    SetVariable("project_name", "petclinic-test").
    SetVariable("environment", "test").
    SetVariable("vpc_cidr", "10.1.0.0/16")
```

## 🏗️ 테스트 작성 가이드

### 1. 새로운 레이어 테스트 추가

```go
// database_test.go
package test

import (
    "testing"
    "github.com/petclinic/terraform-test-common/common"
)

func TestDatabaseLayer(t *testing.T) {
    t.Parallel()
    
    config := common.NewTestConfig(t, "../layers/03-database").
        SetVariable("project_name", "petclinic-test").
        SetVariable("environment", "test")
    
    config.RunUnitTest(t, func(t *testing.T, terraformOptions *terraform.Options) {
        // 테스트 로직
    })
}
```

### 2. 테스트 모범 사례

- **병렬 실행**: `t.Parallel()` 사용으로 테스트 속도 향상
- **고유 이름**: 각 테스트는 고유한 리소스 이름 사용
- **자동 정리**: `defer` 또는 테스트 프레임워크로 리소스 정리
- **의존성 관리**: 레이어 간 의존성을 명확히 정의

### 3. 검증 패턴

```go
// 출력값 검증
expectedOutputs := []string{"vpc_id", "subnet_ids"}
common.ValidateCommonOutputs(t, terraformOptions, expectedOutputs)

// AWS 리소스 검증
awsHelper, _ := common.NewAWSHelper("ap-northeast-2")
awsHelper.ValidateVPCResources(t, terraformOptions)

// 태그 검증
expectedTags := map[string]string{"Environment": "test"}
common.ValidateResourceTags(t, terraformOptions, expectedTags)
```

## 🔍 디버깅

### 테스트 실패 시 디버깅

1. **로그 확인**: 테스트 출력에서 상세 로그 확인
2. **리소스 보존**: 실패한 테스트의 리소스를 보존하여 수동 검사

```go
config.PreserveOnFailure(t, true)  // 실패 시 리소스 보존
```

3. **특정 테스트 실행**: 실패한 테스트만 개별 실행

```bash
make test-specific TEST_NAME=TestNetworkLayer
```

### 일반적인 문제 해결

| 문제 | 원인 | 해결책 |
|------|------|--------|
| AWS 권한 오류 | IAM 권한 부족 | AWS 자격 증명 및 권한 확인 |
| 리소스 이름 충돌 | 동일한 이름의 리소스 존재 | 테스트 ID 고유성 확인 |
| 타임아웃 | 리소스 생성 시간 초과 | 타임아웃 값 증가 |
| 의존성 오류 | 레이어 간 의존성 문제 | 의존성 순서 확인 |

## 📈 CI/CD 통합

### GitHub Actions

```yaml
- name: Run Terraform Tests
  run: |
    cd terraform/test
    make test-ci
```

### 테스트 결과 리포트

```bash
# 커버리지 리포트 생성
make test-coverage

# 테스트 결과 요약
make test-summary
```

## 🔒 보안 고려사항

- **민감 정보**: 테스트에서 실제 프로덕션 데이터 사용 금지
- **리소스 정리**: 테스트 후 모든 AWS 리소스 자동 정리
- **권한 최소화**: 테스트용 IAM 역할에 최소 권한만 부여
- **비용 관리**: 통합 테스트 실행 시 비용 모니터링

## 📚 추가 리소스

- [Terratest 문서](https://terratest.gruntwork.io/)
- [AWS Go SDK](https://docs.aws.amazon.com/sdk-for-go/)
- [Terraform Testing](https://www.terraform.io/docs/extend/testing/index.html)
- [Go Testing](https://golang.org/pkg/testing/)

## 🤝 기여하기

새로운 테스트를 추가하거나 기존 테스트를 개선할 때:

1. 테스트 명명 규칙 준수
2. 적절한 문서화 추가
3. 단위 테스트와 통합 테스트 모두 고려
4. 리소스 정리 로직 포함
5. PR에서 테스트 결과 공유