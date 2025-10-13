# Terraform 변수 구조 마이그레이션 가이드

## 개요

기존 레이어 기반 Terraform 구조에서 **공통 변수 중앙화** 방식으로 마이그레이션합니다.

### 변경 사항 요약

| 항목 | 변경 전 | 변경 후 |
|------|---------|---------|
| 공통 변수 | 각 레이어에 `shared-variables.tf` 복제 | `shared/common.tfvars` 단일 파일 |
| 레이어 변수 | `variables.tf` + `shared-variables.tf` | `variables.tf` (레이어 전용 변수만) |
| 변수 주입 | 환경별 tfvars만 | 공통 tfvars + 환경별 tfvars |
| 스크립트 | 수동 -var-file 지정 | 자동 TF_CLI_ARGS + 스크립트 개선 |

## 마이그레이션 절차

### 1. 파일 구조 변경

```bash
# 기존 구조
terraform/
├── layers/
│   ├── 01-network/
│   │   ├── shared-variables.tf  # ❌ 제거됨
│   │   └── variables.tf         # ✅ 레이어 전용 변수만
│   └── ...

# 신규 구조
terraform/
├── shared/
│   └── common.tfvars           # ✅ 공통 변수
├── envs/
│   ├── dev.tfvars             # ✅ 환경별 변수
│   └── ...
├── layers/
│   ├── 01-network/
│   │   └── variables.tf       # ✅ 레이어 전용 변수만
│   └── ...
└── .envrc                      # ✅ 자동 변수 주입
```

### 2. 변수 분리 원칙

#### shared/common.tfvars (모든 레이어 공통)
```hcl
# 프로젝트 기본 정보
project_name = "PetClinic"
name_prefix = "petclinic-dev"
environment = "dev"

# AWS 설정
aws_region = "ap-northeast-1"
aws_profile = "petclinic-dev"

# 네트워크 기본 설정
vpc_cidr = "10.0.0.0/16"
azs = ["ap-northeast-1a", "ap-northeast-1c"]

# 공통 태그
tags = {
  Project = "petclinic"
  Environment = "dev"
}
```

#### envs/{env}.tfvars (환경별 재정의)
```hcl
# 환경별 값 재정의
name_prefix = "petclinic-prod"  # dev → prod
aws_profile = "petclinic-prod"  # 프로파일 변경
environment = "prod"            # 환경 변경

# 환경별 고유 설정
backup_retention_period = 30    # prod는 30일 백업
```

#### layers/{layer}/variables.tf (레이어 전용)
```hcl
# 레이어 고유 변수만
variable "enable_ipv6" {
  description = "IPv6 활성화"
  type = bool
  default = false
}

variable "instance_class" {
  description = "DB 인스턴스 클래스"
  type = string
  default = "db.serverless"
}
```

### 3. 스크립트 사용법

#### 자동 변수 주입 (권장)
```bash
# direnv 활성화
cd terraform
direnv allow  # .envrc 허용

# 이제 모든 terraform 명령에 자동으로 변수 주입
terraform -chdir=layers/01-network plan
terraform -chdir=layers/03-database apply
```

#### 수동 스크립트 사용
```bash
# 개선된 스크립트 (자동 공통+환경 변수 주입)
./scripts/local/plan-all.sh dev
./scripts/local/apply-all.sh dev

# 개별 레이어 실행
terraform -chdir=layers/01-network plan \
  -var-file=shared/common.tfvars \
  -var-file=envs/dev.tfvars
```

### 4. 변수 우선순위

1. **명시적 -var/-var-file**: CLI에서 직접 지정 (최고 우선순위)
2. **자동 로딩**: TF_CLI_ARGS로 주입된 파일들
3. **기본값**: variables.tf의 default 값

```bash
# 예: 환경변수로 특정 값 재정의
export TF_VAR_instance_class="db.t3.micro"

terraform -chdir=layers/03-database plan
# instance_class는 "db.t3.micro" 사용 (common.tfvars 값 무시)
```

## 주의사항

### 1. 기존 상태 유지
- 마이그레이션 시 기존 Terraform 상태는 유지됩니다
- 레이어 간 의존성은 변경되지 않습니다

### 2. 변수 검증
```bash
# 각 레이어에서 변수 검증
terraform -chdir=layers/01-network validate

# 전체 레이어 검증 스크립트
./scripts/local/validate-infrastructure.sh dev
```

### 3. 롤백 계획
문제가 발생할 경우:
```bash
# 백업에서 복원
cp layers/01-network/variables.tf.backup layers/01-network/variables.tf
cp layers/01-network/shared-variables.tf.backup layers/01-network/shared-variables.tf

# 또는 git revert
git revert HEAD~1
```

## 장점

### 1. 유지보수성 향상
- ✅ 공통 변수 한 곳에서 관리
- ✅ 변경 추적 용이
- ✅ 중복 제거

### 2. 일관성 확보
- ✅ 모든 레이어 동일 변수 구조
- ✅ 환경별 재정의 명확
- ✅ 자동화된 변수 주입

### 3. 개발자 경험 개선
- ✅ direnv로 자동화
- ✅ 스크립트 단순화
- ✅ 휴먼 에러 감소

## 마이그레이션 체크리스트

- [x] shared/common.tfvars 생성
- [x] 각 레이어 shared-variables.tf 제거
- [x] 레이어 variables.tf 정리
- [x] 스크립트 개선 (plan-all.sh, apply-all.sh)
- [x] .envrc 파일 생성
- [ ] 변수 검증 테스트
- [ ] 실제 배포 테스트
- [ ] 팀원 교육 및 공유

## FAQ

**Q: 기존 워크플로우는 어떻게 되나요?**
A: 변경되지 않습니다. direnv를 활성화하면 자동으로 새로운 방식이 적용됩니다.

**Q: 레이어 독립 실행은 여전히 가능한가요?**
A: 네, 각 레이어는 여전히 독립적으로 실행 가능합니다.

**Q: 환경별 변수는 어떻게 관리하나요?**
A: `envs/{env}.tfvars`에서 환경별 값을 재정의합니다.

**Q: direnv가 필수인가요?**
A: 아니요, 스크립트를 사용하거나 수동으로 -var-file을 지정할 수 있습니다.

## 추가 리소스

- [Terraform Variable Precedence](https://www.terraform.io/language/values/variables#variable-definition-precedence)
- [direnv Documentation](https://direnv.net/)
- [Terraform Best Practices](https://www.terraform.io/docs/language/modules/develop/structure.html)