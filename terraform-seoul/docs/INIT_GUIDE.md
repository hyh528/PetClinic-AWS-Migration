# Terraform 초기화 안내서

이 문서는 중앙화된 S3 backend(`terraform/backend.hcl`)와 레이어별 state key(`backend.config`)를 사용해 각 Terraform 레이어를 초기화하는 방법을 설명합니다.

개요
- 공통 backend 설정: `terraform/backend.hcl`에 버킷, 리전, 암호화(encrypt), DynamoDB 락 테이블 등 공통 옵션을 둡니다.
- 레이어별 key: 각 레이어 디렉터리에 `backend.config` 파일을 두어 `key = "dev/<layer>/terraform.tfstate"`처럼 레이어별 state 경로를 관리합니다.

단일 레이어 초기화 (권장)
1. 레이어 디렉터리로 이동합니다. 예: `terraform/layers/02-security`
2. 아래 명령을 실행합니다:

```bash
terraform init -backend-config="../../backend.hcl" -backend-config="backend.config" -reconfigure
```

또는 key를 직접 전달할 수도 있습니다:

```bash
terraform init -backend-config="../../backend.hcl" -backend-config="key=dev/02-security/terraform.tfstate" -reconfigure
```

배치 초기화 (스크립트 사용)
- 저장소에는 모든 레이어를 순차적으로 초기화하는 스크립트가 포함되어 있습니다:
	- Bash: `terraform/scripts/local/init-all.sh`
	- PowerShell: `terraform/scripts/local/init-all.ps1`

	이 스크립트들은 중앙의 `backend.hcl`과 각 레이어의 `backend.config`(또는 자동 생성된 key)를 사용해 `terraform init`을 호출하도록 설계되어 있습니다. 환경(예: dev/staging/prod)을 인자로 전달하면 해당 환경을 반영한 key를 사용합니다.

CI(파이프라인) 권장사항
- CI에서는 AWS 자격증명(예: GitHub Secrets, OIDC 역할 등)을 안전하게 주입하고, 레이어 디렉터리에서 동일한 init 명령을 실행하세요.
- 예 (GitHub Actions job 예시):

```yaml
- name: Terraform Init
	run: |
		cd terraform/layers/02-security
		terraform init -backend-config="../../backend.hcl" -backend-config="backend.config" -reconfigure
	env:
		AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
		AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
```

주의 및 팁
- `backend.config` 파일은 일반적으로 `key` 값만 포함하므로 커밋해도 안전합니다(민감 정보 포함 금지).
- `terraform init`은 실제로 S3/KMS/DynamoDB에 접근하므로 적절한 권한이 있는 자격증명이 필요합니다.
- `.terraform.lock.hcl`은 provider 버전 재현성을 위해 커밋하는 것을 권장합니다.
- 레이어별 key 네이밍 규칙을 명확히 문서화하세요. 예: `dev/01-network/terraform.tfstate`, `prod/01-network/terraform.tfstate`.

추가 지원
- 원하시면 이 문서에 환경별 예시(staging/prod), CI 파이프라인 샘플, 또는 `scripts/init-layer.sh` 같은 단일 레이어 초기화 유틸 스크립트를 추가해 드리겠습니다.

