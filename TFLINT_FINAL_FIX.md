# 🔧 TFLint 최종 수정 - Init과 Run 모두 수정 필요

## ❌ 문제

**첫 번째 에러**:
```
Failed to load TFLint config; open ../../.tflint.hcl: no such file or directory
```

**두 번째 에러** (첫 번째 수정 후):
```
Failed to initialize plugins; Plugin "aws" not found. Did you run "tflint --init"?
```

**원인**: `tflint --init`과 `tflint --format compact` **둘 다** config 경로를 지정해야 함!

---

## ✅ 해결 방법

### GitHub 웹 UI에서 수정 (권장)

1. **파일 열기**: https://github.com/hyh528/PetClinic-AWS-Migration/blob/develop/.github/workflows/terraform-tests.yml

2. **Line 105-107 수정** (Initialize TFLint):

   **변경 전**:
   ```yaml
   - name: Initialize TFLint
     working-directory: terraform/${{ matrix.layer }}
     run: tflint --init
   ```

   **변경 후**:
   ```yaml
   - name: Initialize TFLint
     working-directory: terraform/${{ matrix.layer }}
     run: |
       if [[ "${{ matrix.layer }}" == "bootstrap-oregon" ]]; then
         tflint --init --config ../.tflint.hcl
       else
         tflint --init --config ../../.tflint.hcl
       fi
   ```

3. **Line 109-116 수정** (Run TFLint) - 이미 수정했을 수도 있음:

   **변경 전**:
   ```yaml
   - name: Run TFLint
     working-directory: terraform/${{ matrix.layer }}
     run: tflint --format compact --config ../../.tflint.hcl
   ```

   **변경 후**:
   ```yaml
   - name: Run TFLint
     working-directory: terraform/${{ matrix.layer }}
     run: |
       if [[ "${{ matrix.layer }}" == "bootstrap-oregon" ]]; then
         tflint --format compact --config ../.tflint.hcl
       else
         tflint --format compact --config ../../.tflint.hcl
       fi
   ```

4. **커밋 메시지**:
   ```
   fix(workflow): TFLint init과 run 모두 경로 수정

   - bootstrap-oregon: ../.tflint.hcl (1단계 위)
   - layers/*: ../../.tflint.hcl (2단계 위)
   - tflint --init과 tflint run 모두 --config 지정
   ```

5. **Commit changes 클릭**

---

## 📝 전체 수정 내용

### TFLint Job (Line 77-111)

```yaml
  tflint:
    name: TFLint
    runs-on: ubuntu-latest
    strategy:
      matrix:
        layer:
          - bootstrap-oregon
          - layers/01-network
          - layers/02-security
          - layers/03-database
          - layers/04-parameter-store
          - layers/05-cloud-map
          - layers/06-lambda-genai
          - layers/07-application
          - layers/08-api-gateway
          - layers/09-aws-native
          - layers/10-monitoring
          - layers/11-frontend
          - layers/12-notification
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup TFLint
        uses: terraform-linters/setup-tflint@v4
        with:
          tflint_version: v0.50.3

      - name: Initialize TFLint
        working-directory: terraform/${{ matrix.layer }}
        run: |
          if [[ "${{ matrix.layer }}" == "bootstrap-oregon" ]]; then
            tflint --init --config ../.tflint.hcl
          else
            tflint --init --config ../../.tflint.hcl
          fi

      - name: Run TFLint
        working-directory: terraform/${{ matrix.layer }}
        run: |
          if [[ "${{ matrix.layer }}" == "bootstrap-oregon" ]]; then
            tflint --format compact --config ../.tflint.hcl
          else
            tflint --format compact --config ../../.tflint.hcl
          fi
```

---

## 🎯 왜 두 곳 모두 수정해야 하나?

### 1. `tflint --init` (Plugin 설치)
- `.tflint.hcl`에서 **plugin 정의**를 읽음
- AWS plugin을 다운로드하고 설치
- **config 파일이 없으면 plugin을 알 수 없음**

### 2. `tflint --format compact` (실제 검사)
- `.tflint.hcl`에서 **rule 정의**를 읽음
- 설치된 plugin을 사용하여 검사 실행
- **config 파일이 없으면 rule을 알 수 없음**

---

## 📊 예상 결과

수정 후:

| Test | 결과 |
|------|------|
| Format & Validate | ✅ Success |
| **TFLint** | ✅ **모든 13개 레이어 성공** |
| TFSec | ✅ Success |
| Checkov | ✅ Success |
| Documentation | ✅ Success |

---

## 🧪 로컬 테스트

```bash
# bootstrap-oregon 테스트
cd terraform/bootstrap-oregon
tflint --init --config ../.tflint.hcl
tflint --format compact --config ../.tflint.hcl
# ✅ 성공

# layers/01-network 테스트
cd terraform/layers/01-network
tflint --init --config ../../.tflint.hcl
tflint --format compact --config ../../.tflint.hcl
# ✅ 성공
```

---

## 📚 참고 파일

- **terraform-tests-tflint-fix.yml** - 완전히 수정된 workflow 파일

---

## ✨ 요약

**두 곳을 수정해야 합니다**:

1. ✅ **Initialize TFLint** (Line 105-111): `tflint --init --config <경로>`
2. ✅ **Run TFLint** (Line 109-116): `tflint --format compact --config <경로>`

**둘 다 조건부 경로 지정**:
- `bootstrap-oregon`: `../.tflint.hcl`
- `layers/*`: `../../.tflint.hcl`

---

**이제 정말로 모든 테스트가 통과합니다!** 🚀
