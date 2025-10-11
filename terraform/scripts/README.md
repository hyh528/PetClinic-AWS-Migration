# Terraform Scripts

이 디렉터리는 Terraform 관련 스크립트들을 포함합니다.

## 폴더 구조

```
terraform/scripts/
├── local/          # 로컬 개발 및 운영 스크립트
├── testing/        # 테스트 관련 스크립트 및 설정
└── README.md       # 이 파일
```

## 폴더별 설명

### 📁 local/
로컬 개발 환경에서 사용하는 Terraform 운영 스크립트들
- 인프라 초기화, 계획, 적용, 검증 스크립트
- 문서 생성, 드리프트 감지 등 운영 도구

### 📁 testing/
테스트 자동화 관련 파일들
- 통합 테스트 실행기 (Python)
- 테스트 설정 파일 (YAML)
- 테스트 가이드 문서

## 사용법

### 로컬 개발
```bash
# 모든 레이어 초기화
./scripts/local/init-all.sh dev

# 모든 레이어 계획 생성
./scripts/local/plan-all.sh dev

# 모든 레이어 적용
./scripts/local/apply-all.sh dev

# 인프라 검증
./scripts/local/validate-infrastructure.sh dev
```

### 테스트 실행
```bash
# 통합 테스트 실행
cd scripts/testing
python3 integration_test_runner.py integration-test-enhanced.yaml dev

# 롤백 테스트
./rollback-test.ps1 -Environment dev
```

## 참고 문서

- [로컬 스크립트 가이드](local/README.md)
- [테스트 가이드](testing/README.md)
- [전체 테스트 가이드](../docs/TESTING_GUIDE.md)