# Terraform 테스트 스크립트

이 폴더는 Terraform 인프라의 테스트 자동화를 위한 스크립트와 설정 파일들을 포함합니다.

## 파일 목록

### 🐍 Python 테스트 실행기

| 파일 | 설명 |
|------|------|
| `integration_test_runner.py` | 통합 테스트 메인 실행기 |
| `requirements.txt` | Python 의존성 목록 |

### ⚙️ 테스트 설정

| 파일 | 설명 |
|------|------|
| `integration-test-enhanced.yaml` | 새로운 Python 실행기용 설정 |
| `integration-test-config.yaml` | 기존 Bash 스크립트용 설정 |

### 📜 레거시 스크립트

| 파일 | 설명 |
|------|------|
| `integration-test.sh` | Bash 기반 통합 테스트 (레거시) |
| `integration-test.ps1` | PowerShell 기반 통합 테스트 (레거시) |
| `rollback-test.ps1` | 롤백 시나리오 테스트 |

### 📚 문서

| 파일 | 설명 |
|------|------|
| `INTEGRATION_TEST_GUIDE.md` | 통합 테스트 상세 가이드 |

## 사용법

### Python 통합 테스트 실행 (권장)

```bash
# 1. 의존성 설치
pip install -r requirements.txt

# 2. AWS 자격 증명 설정
export AWS_PROFILE=petclinic-dev
export AWS_REGION=ap-northeast-1

# 3. 전체 테스트 실행
python3 integration_test_runner.py integration-test-enhanced.yaml dev

# 4. 특정 테스트 스위트만 실행
python3 integration_test_runner.py integration-test-enhanced.yaml dev --verbose

# 5. 결과를 파일로 저장
python3 integration_test_runner.py integration-test-enhanced.yaml dev -o results.json
```

### 레거시 Bash 스크립트 실행

```bash
# 전체 통합 테스트
./integration-test.sh -e dev -t full

# 특정 테스트만 실행
./integration-test.sh -e dev -t deploy

# 롤백 테스트 포함
./integration-test.sh -e dev --test-rollback

# 상태 잠금 테스트 포함
./integration-test.sh -e dev --test-state-locking
```

### PowerShell 스크립트 실행

```powershell
# 기본 통합 테스트
./integration-test.ps1 -Environment dev

# 롤백 테스트
./rollback-test.ps1 -Environment dev
```

## 테스트 유형

### 1. 네트워크 연결성 테스트
- 퍼블릭 서브넷 인터넷 연결성
- 프라이빗 서브넷 격리
- VPC 엔드포인트 접근성

### 2. 서비스 상태 테스트
- ECS 클러스터 및 서비스 상태
- Lambda 함수 활성화 상태

### 3. 데이터베이스 테스트
- Aurora 클러스터 가용성
- 클러스터 멤버 상태

### 4. 보안 컴플라이언스 테스트
- 보안 그룹 규칙 검증
- IAM 최소 권한 원칙

### 5. 애플리케이션 엔드포인트 테스트
- ALB 헬스체크
- API Gateway 응답성

## 설정 파일 구조

### integration-test-enhanced.yaml
```yaml
test_suites:
  - name: "network_connectivity"
    tests:
      - name: "vpc_internet_connectivity"
        type: "network"
        target: "public_subnets"
        timeout: 60

execution_config:
  parallel_execution: true
  max_workers: 5
  
environments:
  dev:
    timeout_multiplier: 1.0
```

## 환경별 설정

### 개발 환경 (dev)
- 빠른 실행을 위한 짧은 타임아웃
- 모든 테스트 실행

### 스테이징 환경 (staging)
- 중간 타임아웃 설정
- 프로덕션과 유사한 테스트

### 프로덕션 환경 (prod)
- 긴 타임아웃 설정
- 일부 보안 테스트 스킵

## 결과 해석

### 성공 예시
```json
{
  "summary": {
    "total_tests": 12,
    "passed": 12,
    "failed": 0,
    "success_rate": "100.0%",
    "overall_status": "PASS"
  }
}
```

### 실패 예시
```json
{
  "summary": {
    "total_tests": 12,
    "passed": 10,
    "failed": 2,
    "success_rate": "83.3%",
    "overall_status": "FAIL"
  },
  "results": [
    {
      "name": "service_health.ecs_services_running",
      "status": "FAIL",
      "message": "Only 1/2 services are healthy"
    }
  ]
}
```

## 트러블슈팅

### 일반적인 문제

#### 1. Python 의존성 오류
```bash
# 가상환경 생성 및 활성화
python3 -m venv venv
source venv/bin/activate  # Linux/Mac
# 또는
venv\Scripts\activate     # Windows

# 의존성 재설치
pip install -r requirements.txt
```

#### 2. AWS 권한 오류
```bash
# 자격 증명 확인
aws sts get-caller-identity

# 필요한 권한 확인
aws iam simulate-principal-policy \
  --policy-source-arn $(aws sts get-caller-identity --query Arn --output text) \
  --action-names ec2:DescribeVpcs \
  --resource-arns "*"
```

#### 3. 테스트 타임아웃
```yaml
# integration-test-enhanced.yaml에서 타임아웃 조정
environments:
  dev:
    timeout_multiplier: 2.0  # 2배로 증가
```

#### 4. 네트워크 연결 실패
```bash
# VPC 상태 확인
aws ec2 describe-vpcs --filters "Name=tag:Environment,Values=dev"

# 서브넷 상태 확인
aws ec2 describe-subnets --filters "Name=vpc-id,Values=vpc-xxxxx"
```

## CI/CD 통합

이 테스트들은 GitHub Actions에서 자동으로 실행됩니다:

- **PR 시**: 변경된 모듈의 단위 테스트
- **배포 후**: 전체 통합 테스트
- **수동 실행**: 특정 테스트 스위트

자세한 내용은 [전체 테스트 가이드](../../docs/TESTING_GUIDE.md)를 참조하세요.

## 참고 문서

- [전체 테스트 가이드](../../docs/TESTING_GUIDE.md)
- [통합 테스트 상세 가이드](INTEGRATION_TEST_GUIDE.md)
- [GitHub Actions 워크플로우](../../../.github/workflows/)