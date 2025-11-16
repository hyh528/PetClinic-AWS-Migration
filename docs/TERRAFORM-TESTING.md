# Terraform 테스트 가이드 (초보자용)

이 문서는 이 리포지토리에서 Terraform 코드를 안전하게 테스트하기 위한 단계별 가이드입니다.
한국어로, 로컬/CI/간단한 통합(테라테스트) 예제까지 포함합니다.

## 목차
- 개요
- 빠른 체크 리스트
- 로컬에서의 기본 검사(형식/유효성)
- 정적 보안 스캐닝 (tflint / tfsec / Checkov)
- 모듈 단위(유닛) 테스트
- 간단한 통합 테스트 (Terratest 사용 예제)
- CI 통합 예시 (GitHub Actions)
- 안전 팁, 흔한 문제와 해결


## 개요
테라폼 테스트는 크게 세 단계로 생각하면 쉽습니다:
1. 정적 검사: 포맷/문법/정책/보안 스캔
2. 모듈/plan 수준 검사: init/validate/plan으로 논리적 변경 확인
3. 통합/엔드투엔드: 실제 리소스 apply → 검증 → destroy (비용/권한 주의)


## 빠른 체크 리스트
- [ ] terraform fmt -check -recursive
- [ ] terraform init -backend=false && terraform validate
- [ ] tflint / tfsec / checkov 스캔
- [ ] 모듈별 plan 확인
- [ ] (선택) Terratest로 apply/검증/destroy 자동화


## 1) 로컬에서 빠르게(형식·구문 검사)
다음은 가장 먼저 실행할 커맨드입니다. 리눅스(bash)와 Windows(PowerShell) 예시를 함께 둡니다.

bash:
```bash
# repository 루트에서
terraform fmt -check -recursive
cd terraform/layers/07-application
terraform init -backend=false
terraform validate
terraform plan -var-file=../../envs/dev.tfvars -out=tfplan
```

PowerShell:
```powershell
terraform fmt -check -recursive
Set-Location terraform/layers/07-application
terraform init -backend=false
terraform validate
terraform plan -var-file=../../envs/dev.tfvars -out=tfplan
```

주의: `-backend=false` 옵션은 로컬에서 원격 상태를 건드리지 않고 모듈/검증만 수행할 때 유용합니다.


## 2) 정적 보안/정책 스캔
권장 툴:
- tflint: 테라폼 스타일/베스트프랙티스
- tfsec: 보안 취약점 검출
- Checkov (Bridgecrew): 정책/규칙 기반 스캔

간단 사용법(bash):
```bash
# tfsec
curl -sSfL https://raw.githubusercontent.com/aquasecurity/tfsec/master/scripts/install_linux.sh | bash
tfsec terraform/

# checkov (pip)
pip install checkov
checkov -d terraform/

# tflint (설치 후)
tflint --init
tflint --recursive terraform/
```

GitHub Actions에서 위 툴들을 사용하면 PR에서 자동으로 보안/정책을 검사할 수 있습니다.


## 3) 모듈 단위(유닛) 테스트 패턴
모듈 디렉토리에서 다음 패턴을 사용합니다:

```bash
cd terraform/modules/<module-name>
terraform init -backend=false
terraform validate
terraform plan -var-file=../../envs/dev.tfvars -out=tfplan
terraform show -json tfplan | jq '.'
```

`terraform show -json` 결과를 jq로 검사해, 특정 리소스 속성(예: 인스턴스 타입, 태그 등)이 기대값인지 확인하는 자동화 스크립트를 만들면 편합니다.


## 4) 간단한 통합 테스트: Terratest 예제
Terratest(Go 기반)를 사용하면 `apply` → 검증 → `destroy` 를 자동화할 수 있습니다. 아래는 최소 예제입니다.

파일: `test/go.mod` (예제용)
```go
module github.com/hyh528/petclinic-testing

go 1.20

require (
    github.com/gruntwork-io/terratest v0.44.9
    github.com/stretchr/testify v1.8.4
)
```

파일: `test/terratest_example_test.go`
```go
package test

import (
    "testing"

    "github.com/gruntwork-io/terratest/modules/terraform"
    "github.com/stretchr/testify/assert"
)

func TestExampleModule(t *testing.T) {
    t.Parallel()

    // Terraform code가 있는 폴더 경로
    terraformDir := "../terraform/modules/example-bucket"

    options := &terraform.Options{
        TerraformDir: terraformDir,
        Vars: map[string]interface{}{
            // module inputs
            "bucket_name": "terratest-example-12345",
        },
        EnvVars: map[string]string{
            "AWS_DEFAULT_REGION": "ap-southeast-2",
        },
    }

    // 테스트가 끝나면 반드시 destroy 수행
    defer terraform.Destroy(t, options)

    // init & apply
    terraform.InitAndApply(t, options)

    // output 읽어 검증
    id := terraform.Output(t, options, "bucket_id")
    assert.Contains(t, id, "terratest-example-")
}
```

실행 방법:
```bash
cd test
# 최초: go 모듈 의존성 다운로드
go mod tidy
# 테스트 실행
go test -v ./ -run TestExampleModule
```

주의사항:
- Terratest는 실제로 AWS 리소스를 생성합니다. 반드시 테스트용 계정/리전/테스트 전용 상태(또는 임시 리소스)를 사용하세요.
- 테스트에 실패해도 `defer terraform.Destroy(...)`가 동작하도록 작성해야 비용 누수를 막습니다.


## 5) GitHub Actions에서 자동화(예: PR 체크)
아래는 PR에서 실행할 최소 파이프라인 예시입니다. (파일: `.github/workflows/terraform-pr-check.yml`)

```yaml
name: Terraform PR checks
on:
  pull_request:
    paths:
      - 'terraform/**'

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.12.0

      - name: Terraform fmt
        run: terraform fmt -check -recursive

      - name: Terraform init
        working-directory: terraform/layers/07-application
        run: terraform init -backend=false

      - name: Terraform validate
        working-directory: terraform/layers/07-application
        run: terraform validate

      - name: Run tfsec
        run: |
          curl -sSfL https://raw.githubusercontent.com/aquasecurity/tfsec/master/scripts/install_linux.sh | bash
          tfsec terraform/

      - name: Run checkov
        uses: bridgecrewio/checkov-action@v12
        with:
          directory: terraform/

      - name: Terraform plan
        working-directory: terraform/layers/07-application
        run: terraform plan -var-file=${{ github.workspace }}/terraform/envs/dev.tfvars -out=tfplan -no-color
```

> 참고: Terratest를 CI에서 실행하려면 테스트에 필요한 권한/비용을 고려하세요. 보통 Terratest는 별도의 `integration` 워크플로에서 수동으로 트리거하거나 스테이징 환경에서만 실행합니다.


## 6) 권한·비밀(Secrets) 설정
CI에서 AWS에 접근하려면 다음 비밀을 설정하세요:
- `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` (짧은 기간의 키 권장)
- 또는 `role-to-assume` 형태로 `aws-actions/configure-aws-credentials` 사용
- ECR 사용 시: `ECR_REGISTRY` 같은 이미지 리포지토리 식별자

권한은 최소 권한(least privilege) 원칙을 적용하세요.


## 7) 안전 팁 / 베스트 프랙티스
- 테스트 전용 리소스 네임스페이스(프리픽스) 사용: `test-<id>-...`
- 상태(state) 분리: 테스트 전용 state bucket 사용
- 비용 통제: 통합 테스트는 비싼 리소스(예: RDS, EC2)를 사용하지 않도록 하거나 미니멀 사이즈로 대체
- 파괴 보장: try/finally 또는 Go의 defer로 반드시 destroy 호출
- 병렬 제한: 같은 state에 대해 병렬 apply 금지


## 8) 문제 발생 시 진단 체크리스트
- `terraform init` 실패: backend config / 권한 확인
- plan 에서 의도치 않은 변경: 변수 파일(.tfvars) 확인
- Terratest에서 destroy 안 됨: AWS 권한/네트워크 오류 로그 확인
- CI에서 secrets 오류: repository / organization secrets 권한 확인


---

문서를 더 맞춤화(예: 귀하의 repo에서 실제로 실행 가능한 Terratest 모듈 추가, CI에서 Terratest 실행 워크플로 추가)하기 원하시면 알려주세요. 바로 예제 모듈을 만들거나 `.github/workflows`에 연계 워크플로를 추가해 드리겠습니다.

## 워크플로우 사용법 및 디버깅

이 리포지토리에 추가된 GitHub Actions 워크플로우의 동작 원리, 로컬에서 디버깅하는 방법, 그리고 PR에서 스캔 대상을 제한하는 동작 방식을 설명합니다.

1) 워크플로우 개요

- `build-and-push-images.yml`: 각 서비스의 이미지를 빌드하고 ECR에 푸시합니다. 빌드 후 `images.properties` 아티팩트를 만들어 Terraform에 전달할 수 있게 합니다.
- `terraform-ci.yml`: PR에서 Terraform 정적·보안 스캔(tflint/tfsec/checkov)과 레이어 단위의 plan을 수행합니다. 변경 감지 로직은 PR과 `origin/main`의 diff를 사용합니다.

2) 변경된 경로 감지 (paths 출력)

- 워크플로우는 `git fetch origin main` 후 `git diff --name-only origin/main...HEAD`로 변경된 파일 목록을 계산합니다.
- 변경된 파일이 `terraform/modules/<name>/...` 또는 `terraform/layers/<name>/...`에 속하면 해당 모듈/레이어의 경로를 `|`(파이프)로 구분한 단일 라인 문자열로 `paths` 출력에 설정합니다.
- 예시 출력: `terraform/modules/foo|terraform/layers/07-application`

3) 로컬에서 워크플로우 디버깅

- GitHub Actions의 런타임을 그대로 재현하려면 `actions/checkout` 단계 후에 run 스텝에서 동일한 스크립트를 실행해 보세요. 핵심 명령은 다음과 같습니다 (PowerShell 예):

```powershell
# 변경 감지 예시
git fetch origin main
$changed = git diff --name-only origin/main...HEAD
Write-Output $changed

# paths 생성 (PowerShell)
$paths = $changed | ForEach-Object {
  if ($_ -match '^terraform\\/modules\\/([^\\/]+)') { "terraform/modules/$($matches[1])" }
  elseif ($_ -match '^terraform\\/layers\\/([^\\/]+)') { "terraform/layers/$($matches[1])" }
}
$pathsLine = ($paths -join '|')
Write-Output $pathsLine
```

- 로컬에서 `tflint`를 특정 경로로 실행하려면:

```powershell
tflint --init
foreach ($p in $pathsLine -split '\|') { Push-Location $p; tflint --init; tflint; Pop-Location }
```

4) images.properties와 Terraform 연결

- `build-and-push-images.yml`는 각 서비스(예: customers-service)에 대해 키=값 형식의 `images.properties` 파일을 생성합니다:

```
customers-service=123456789012.dkr.ecr.ap-southeast-2.amazonaws.com/customers-service:2025-10-01-abc123
vets-service=123456789012.dkr.ecr.ap-southeast-2.amazonaws.com/vets-service:2025-10-01-abc123
```

- Terraform에서는 이 파일의 내용을 `service_image_map` 변수로 전달하여 `lookup(var.service_image_map, "customers-service")` 형태로 사용합니다.

5) 디버깅 팁

- 워크플로우 로그에서 'Detect changed terraform paths' 단계 출력을 먼저 확인하세요. 이 값이 비어 있으면 전체 스캔(폴백)이 수행됩니다.
- YAML에서 멀티라인 워크플로우 출력은 구문 오류를 유발할 수 있으므로 이 리포지토리의 구현은 파이프(`|`)로 연결된 단일 라인 형식을 사용합니다.
- Secrets 문제: CI에서 AWS 자격증명은 리포지토리/오거나니제이션 시크릿으로 설정되어야 합니다. 로컬 디버깅 시에는 `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY` 또는 `aws-vault`/profile을 사용하세요.

6) 자주 묻는 질문

- Q: tfsec/checkov를 변경된 모듈만 스캔하게 할 수 있나요?
  - A: 예. 현재 `terraform-ci.yml`는 tflint만 변경된 경로로 제한하여 실행합니다. 동일한 `paths` 출력을 이용해 tfsec와 checkov를 대상 경로로 제한하도록 쉽게 확장할 수 있습니다. 원하시면 제가 바로 변경해 드리겠습니다.

---

완료: 워크플로우 사용법 섹션을 추가했습니다. 다음으로 원하시면 (A) tfsec/checkov를 변경된 경로만 스캔하도록 업데이트하거나 (B) terraform plan을 변경된 레이어로만 실행하도록 하겠습니다.