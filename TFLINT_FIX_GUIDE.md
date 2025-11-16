# 🔧 TFLint bootstrap-oregon 경로 수정

## ❌ 문제

**에러 메시지**:
```
Failed to load TFLint config; failed to load file: open ../../.tflint.hcl: no such file or directory
```

**원인**: `bootstrap-oregon`과 `layers/XX`의 디렉토리 깊이가 다름
- `terraform/bootstrap-oregon/` → `.tflint.hcl`까지: `../.tflint.hcl` (1단계 위)
- `terraform/layers/XX/` → `.tflint.hcl`까지: `../../.tflint.hcl` (2단계 위)

---

## ✅ 해결 방법

### GitHub 웹 UI에서 수정 (권장)

1. **파일 열기**: https://github.com/hyh528/PetClinic-AWS-Migration/blob/develop/.github/workflows/terraform-tests.yml

2. **Line 109-111 수정**:

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

3. **커밋 메시지**:
   ```
   fix(workflow): TFLint bootstrap-oregon 경로 수정

   - bootstrap-oregon: ../.tflint.hcl (1단계 위)
   - layers/*: ../../.tflint.hcl (2단계 위)
   - 조건부 경로 지정으로 해결
   ```

4. **Commit changes 클릭**

---

## 📂 디렉토리 구조

```
terraform/
├── .tflint.hcl              # TFLint 설정 파일
├── bootstrap-oregon/        # 1단계 위 (../)
│   ├── main.tf
│   └── ...
└── layers/                  # 
    ├── 01-network/          # 2단계 위 (../../)
    ├── 02-security/         # 2단계 위 (../../)
    └── ...
```

---

## 🎯 예상 결과

수정 후:
- ✅ **bootstrap-oregon**: `../.tflint.hcl` 사용
- ✅ **layers/XX**: `../../.tflint.hcl` 사용
- ✅ **모든 레이어에서 TFLint 성공**

---

## 📝 로컬 테스트

```bash
# bootstrap-oregon 테스트
cd terraform/bootstrap-oregon
tflint --format compact --config ../.tflint.hcl
# ✅ 성공

# layers/01-network 테스트
cd terraform/layers/01-network
tflint --format compact --config ../../.tflint.hcl
# ✅ 성공
```

---

## 📚 참고 파일

- **terraform-tests-tflint-fix.yml** - 수정된 전체 workflow 파일

---

**이 수정으로 TFLint가 모든 레이어에서 정상 작동합니다!** 🚀
