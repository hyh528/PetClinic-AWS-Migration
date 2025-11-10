# 🔧 Terraform Tests Workflow 수정 완료

## ✅ 수정된 내용

### 1. **Terraform 코드 수정 완료** ✅ (커밋 완료: 9ab3b636)

다음 파일들이 수정되어 develop 브랜치에 푸시되었습니다:

- **terraform/layers/10-monitoring/main.tf** - 포맷팅 수정
- **terraform/modules/alb/main.tf** - WAF 로깅 설정 문법 오류 수정
- **terraform/modules/cloudwatch/main.tf** - 포맷팅 수정

**문제**: WAF 로깅 설정 주석 블록 뒤에 `redacted_fields`, `depends_on` 블록이 주석 처리되지 않아 문법 오류 발생
**해결**: 해당 블록들을 주석 내부로 이동

### 2. **Workflow 파일 수정 필요** ⚠️ (수동 작업 필요)

GitHub App에 `workflows` 권한이 없어 자동 푸시가 불가능합니다.

---

## 🚨 수정이 필요한 문제들

### 문제 1: 잘못된 레이어 이름 (가장 중요!)

**현재 workflow에 있는 이름** (잘못됨):
- `layers/04-discovery`
- `layers/05-ecs`
- `layers/06-backend`
- `layers/07-config`

**실제 존재하는 레이어 이름**:
- `layers/04-parameter-store`
- `layers/05-cloud-map`
- `layers/06-lambda-genai`
- `layers/07-application`

### 문제 2: SARIF 파일 경로 문제

**TFSec**:
- 현재: `results.sarif` 파일이 생성되지 않음
- 수정: `--out results.sarif` 추가, 파일 존재 확인 후 업로드

**Checkov**:
- 현재: `results.sarif` 파일명이 TFSec과 충돌
- 수정: `checkov-results.sarif`로 파일명 변경, 파일 존재 확인 후 업로드

---

## 📋 수동 수정 방법

### 옵션 1: GitHub 웹 UI에서 직접 수정 (권장)

1. **파일 열기**: https://github.com/hyh528/PetClinic-AWS-Migration/blob/develop/.github/workflows/terraform-tests.yml

2. **Edit 버튼 클릭**

3. **3군데 matrix.layer 섹션 모두 수정** (line 28-42, 82-96, 170-184):

   **변경 전**:
   ```yaml
   matrix:
     layer:
       - bootstrap-oregon
       - layers/01-network
       - layers/02-security
       - layers/03-database
       - layers/04-discovery        # ❌ 잘못됨
       - layers/05-ecs              # ❌ 잘못됨
       - layers/06-backend          # ❌ 잘못됨
       - layers/07-config           # ❌ 잘못됨
       - layers/08-api-gateway
       - layers/09-aws-native
       - layers/10-monitoring
       - layers/11-frontend
       - layers/12-notification
   ```

   **변경 후**:
   ```yaml
   matrix:
     layer:
       - bootstrap-oregon
       - layers/01-network
       - layers/02-security
       - layers/03-database
       - layers/04-parameter-store  # ✅ 올바름
       - layers/05-cloud-map        # ✅ 올바름
       - layers/06-lambda-genai     # ✅ 올바름
       - layers/07-application      # ✅ 올바름
       - layers/08-api-gateway
       - layers/09-aws-native
       - layers/10-monitoring
       - layers/11-frontend
       - layers/12-notification
   ```

4. **TFSec SARIF 수정** (line 123-136):

   **변경 전**:
   ```yaml
   - name: Run TFSec
     uses: aquasecurity/tfsec-action@v1.0.3
     with:
       working_directory: terraform
       format: sarif
       soft_fail: false
       additional_args: --config-file .tfsec.yml

   - name: Upload TFSec SARIF
     if: always()
     uses: github/codeql-action/upload-sarif@v3
     with:
       sarif_file: results.sarif
       category: tfsec
   ```

   **변경 후**:
   ```yaml
   - name: Run TFSec
     uses: aquasecurity/tfsec-action@v1.0.3
     with:
       working_directory: terraform
       format: sarif,default
       soft_fail: false
       additional_args: --config-file .tfsec.yml --out results.sarif

   - name: Upload TFSec SARIF
     if: always() && hashFiles('results.sarif') != ''
     uses: github/codeql-action/upload-sarif@v3
     with:
       sarif_file: results.sarif
       category: tfsec
   ```

5. **Checkov SARIF 수정** (line 148-163):

   **변경 전**:
   ```yaml
   - name: Run Checkov
     uses: bridgecrewio/checkov-action@v12
     with:
       directory: terraform/
       framework: terraform
       config_file: terraform/.checkov.yml
       soft_fail: true
       output_format: cli,sarif
       output_file_path: console,results.sarif

   - name: Upload Checkov SARIF
     if: always()
     uses: github/codeql-action/upload-sarif@v3
     with:
       sarif_file: results.sarif
       category: checkov
   ```

   **변경 후**:
   ```yaml
   - name: Run Checkov
     id: checkov
     uses: bridgecrewio/checkov-action@v12
     with:
       directory: terraform/
       framework: terraform
       config_file: terraform/.checkov.yml
       soft_fail: true
       output_format: cli,sarif
       output_file_path: console,checkov-results.sarif
     continue-on-error: true

   - name: Upload Checkov SARIF
     if: always() && hashFiles('checkov-results.sarif') != ''
     uses: github/codeql-action/upload-sarif@v3
     with:
       sarif_file: checkov-results.sarif
       category: checkov
   ```

6. **커밋 메시지**:
   ```
   fix(workflow): Terraform 테스트 워크플로우 레이어 이름 및 SARIF 경로 수정

   - 레이어 이름 수정: discovery/ecs/backend/config → parameter-store/cloud-map/lambda-genai/application
   - TFSec: SARIF 출력 경로 명시 (--out results.sarif)
   - Checkov: SARIF 파일명 변경 (checkov-results.sarif)
   - SARIF 업로드 전 파일 존재 여부 확인 추가
   ```

7. **Commit changes 클릭**

### 옵션 2: 로컬에서 파일 복사 (대안)

```bash
# 수정된 파일 복사
cp terraform-tests-fixed.yml .github/workflows/terraform-tests.yml

# 직접 커밋 및 푸시 (GitHub 웹이나 권한이 있는 계정 필요)
git add .github/workflows/terraform-tests.yml
git commit -m "fix(workflow): Terraform 테스트 워크플로우 수정"
git push origin develop
```

---

## 🔍 수정 후 확인사항

1. **Workflow 실행**: develop 브랜치에 push하면 자동으로 실행됩니다
2. **Actions 탭 확인**: https://github.com/hyh528/PetClinic-AWS-Migration/actions
3. **예상 결과**:
   - ✅ Terraform Format & Validate: 모든 레이어 성공
   - ✅ TFLint: 경고는 있을 수 있지만 실행 성공
   - ✅ TFSec: SARIF 업로드 성공 (GitHub Security 탭에 표시)
   - ✅ Checkov: soft-fail이므로 경고만 출력
   - ✅ Terraform Docs: 모든 레이어에 README.md 존재 확인

---

## 📝 참고 파일

- **terraform-tests-fixed.yml** - 수정 완료된 전체 workflow 파일
- **커밋**: https://github.com/hyh528/PetClinic-AWS-Migration/commit/9ab3b636

---

## 💡 추가 개선 사항

Workflow가 정상 작동하면:

1. **TFLint 규칙 조정**: 필요시 `terraform/.tflint.hcl` 수정
2. **TFSec 제외 규칙 조정**: 필요시 `terraform/.tfsec.yml` 수정
3. **Checkov 제외 규칙 조정**: 필요시 `terraform/.checkov.yml` 수정

자세한 내용은 `terraform/TESTING.md` 참조하세요.
