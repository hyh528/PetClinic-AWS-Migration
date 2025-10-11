# 로컬 Terraform 스크립트

이 폴더는 로컬 개발 환경에서 Terraform을 운영하기 위한 스크립트들을 포함합니다.

## 스크립트 목록

### 🚀 배포 스크립트

| 스크립트 | 설명 | 사용법 |
|---------|------|--------|
| `init-all.sh/.ps1` | 모든 레이어 초기화 | `./init-all.sh dev` |
| `plan-all.sh/.ps1` | 모든 레이어 계획 생성 | `./plan-all.sh dev` |
| `apply-all.sh` | 모든 레이어 순차 적용 | `./apply-all.sh dev` |
| `init-layer.ps1` | 특정 레이어 초기화 | `./init-layer.ps1 -Layer 01-network -Environment dev` |

### 🔍 검증 스크립트

| 스크립트 | 설명 | 사용법 |
|---------|------|--------|
| `validate-infrastructure.sh/.ps1` | 인프라 검증 | `./validate-infrastructure.sh dev` |
| `validate-dependencies.sh` | 의존성 검증 | `./validate-dependencies.sh` |
| `drift-detect.sh` | 드리프트 감지 | `./drift-detect.sh dev` |

### 📚 문서화 스크립트

| 스크립트 | 설명 | 사용법 |
|---------|------|--------|
| `terraform-docs-gen.sh` | Terraform 문서 생성 | `./terraform-docs-gen.sh` |
| `setup-shared-files.ps1` | 공유 파일 설정 | `./setup-shared-files.ps1` |

## 사용 예시

### 전체 인프라 배포
```bash
# 1. 모든 레이어 초기화
./init-all.sh dev

# 2. 계획 확인
./plan-all.sh dev

# 3. 적용 (의존성 순서대로)
./apply-all.sh dev

# 4. 검증
./validate-infrastructure.sh dev
```

### 특정 레이어만 작업
```powershell
# PowerShell에서 특정 레이어 초기화
./init-layer.ps1 -Layer "01-network" -Environment dev

# 해당 레이어 디렉터리에서 직접 작업
cd ../layers/01-network
terraform plan -var-file=../../envs/dev.tfvars
terraform apply
```

### 인프라 상태 확인
```bash
# 드리프트 감지
./drift-detect.sh dev

# 의존성 검증
./validate-dependencies.sh

# 전체 인프라 검증
./validate-infrastructure.sh dev
```

## 환경 설정

### 필수 요구사항
- Terraform >= 1.8.5
- AWS CLI 설정 완료
- 적절한 AWS 권한

### 환경 변수
```bash
export AWS_PROFILE=petclinic-dev
export AWS_REGION=ap-northeast-1
```

### PowerShell 실행 정책 (Windows)
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

## 트러블슈팅

### 일반적인 문제

#### 1. 권한 오류
```bash
# AWS 자격 증명 확인
aws sts get-caller-identity --profile petclinic-dev

# 권한 확인
aws iam get-user --profile petclinic-dev
```

#### 2. 상태 잠금 오류
```bash
# 강제 잠금 해제 (주의!)
terraform force-unlock <LOCK_ID>
```

#### 3. 의존성 오류
```bash
# 의존성 검증
./validate-dependencies.sh

# 레이어 순서 확인
cat ../docs/LAYER_EXECUTION_ORDER.md
```

## 베스트 프랙티스

1. **항상 계획 먼저**: `apply` 전에 반드시 `plan` 실행
2. **환경 분리**: 환경별로 별도의 AWS 프로파일 사용
3. **백업**: 중요한 변경 전 상태 파일 백업
4. **검증**: 배포 후 반드시 검증 스크립트 실행
5. **문서화**: 변경사항은 CHANGELOG.md에 기록

## 참고 문서

- [Terraform 사용 가이드](../../USAGE.md)
- [레이어 실행 순서](../../docs/LAYER_EXECUTION_ORDER.md)
- [운영 가이드](../../OPERATIONS_GUIDE.md)