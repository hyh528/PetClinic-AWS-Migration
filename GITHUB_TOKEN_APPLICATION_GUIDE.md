# GITHUB_TOKEN 적용 위치 가이드

## 📍 정확한 적용 위치

### ✅ 수정해야 할 파일:
```
.github/workflows/terraform-tests.yml
```

### ✅ 수정해야 할 위치:
**Line 107-114** (TFLint Job의 "Initialize TFLint" step)

## 🔧 적용 방법

### Before (현재 상태 - Rate Limit 발생):
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

### After (수정 필요 - Rate Limit 해결):
```yaml
      - name: Initialize TFLint
        working-directory: terraform/${{ matrix.layer }}
        env:                                          # 👈 이 2줄 추가!
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}  # 👈
        run: |
          if [[ "${{ matrix.layer }}" == "bootstrap-oregon" ]]; then
            tflint --init --config ../.tflint.hcl
          else
            tflint --init --config ../../.tflint.hcl
          fi
```

## 📋 전체 TFLint Job 구조

```yaml
  tflint:
    name: TFLint
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        layer:
          - bootstrap-oregon
          - layers/01-network
          - layers/02-security
          # ... 나머지 10개 레이어
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup TFLint
        uses: terraform-linters/setup-tflint@v4
        with:
          tflint_version: v0.50.3

      - name: Initialize TFLint              # 👈 여기에 추가!
        working-directory: terraform/${{ matrix.layer }}
        env:                                  # 👈 이 부분 추가
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          if [[ "${{ matrix.layer }}" == "bootstrap-oregon" ]]; then
            tflint --init --config ../.tflint.hcl
          else
            tflint --init --config ../../.tflint.hcl
          fi

      - name: Run TFLint
        working-directory: terraform/${{ matrix.layer }}
        run: |
          # ... TFLint 실행
```

## 🎯 왜 이 위치인가?

### 문제 발생 지점:
```bash
# TFLint 초기화 시 AWS 플러그인 다운로드
tflint --init --config ../.tflint.hcl

# 내부적으로 이런 API 호출이 발생:
GET https://api.github.com/repos/terraform-linters/tflint-ruleset-aws/releases/tags/v0.30.0
        ↑
        이 요청이 Rate Limit에 걸림!
```

### 해결 위치:
- **`tflint --init`** 명령어가 실행되는 step
- **"Initialize TFLint"** step에 환경변수 추가
- GitHub API 호출 시 자동으로 `GITHUB_TOKEN` 사용

## 🔍 동작 원리

### GITHUB_TOKEN이 없을 때:
```
TFLint --init
  └─> AWS Plugin 다운로드
      └─> GitHub API 호출 (익명)
          └─> Rate Limit: 60회/시간
              └─> 13개 레이어 × 동시 실행 = 초과! ❌
```

### GITHUB_TOKEN이 있을 때:
```
TFLint --init
  └─> AWS Plugin 다운로드
      └─> GitHub API 호출 (인증됨)
          └─> env.GITHUB_TOKEN 자동 사용
              └─> Rate Limit: 1,000회/시간
                  └─> 13개 레이어 × 동시 실행 = 여유 있음! ✅
```

## 📊 Rate Limit 비교

| 인증 방식 | 시간당 제한 | 13개 레이어 처리 | 상태 |
|-----------|-------------|------------------|------|
| **익명 (현재)** | 60회 | 3-4개에서 실패 | ❌ 불가능 |
| **GITHUB_TOKEN (적용 후)** | 1,000회 | 모두 성공 | ✅ 가능 |

## 🛠️ 적용 방법 (단계별)

### Option 1: GitHub 웹 UI에서 수정 (권장)

1. **GitHub 저장소로 이동**:
   ```
   https://github.com/hyh528/PetClinic-AWS-Migration
   ```

2. **파일 열기**:
   ```
   .github/workflows/terraform-tests.yml
   ```

3. **Edit 버튼 클릭** (연필 아이콘)

4. **Line 107 찾기** (Ctrl+F로 "Initialize TFLint" 검색)

5. **수정**:
   ```yaml
   - name: Initialize TFLint
     working-directory: terraform/${{ matrix.layer }}
     env:                                          # 👈 추가
       GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}  # 👈 추가
     run: |
   ```

6. **Commit 메시지 작성**:
   ```
   fix: Add GITHUB_TOKEN to TFLint init step to prevent rate limiting
   
   - Add GITHUB_TOKEN environment variable to Initialize TFLint step
   - Increases GitHub API rate limit from 60 to 1,000 requests/hour
   - Fixes 403 rate limit errors in layers/02-security and other layers
   - Enables all 13 matrix jobs to download TFLint AWS plugin successfully
   ```

7. **"Commit changes" 버튼 클릭**

### Option 2: 로컬 백업 파일 사용

로컬에 수정된 파일이 저장되어 있습니다:
```
terraform-tests-with-github-token.yml
```

이 파일의 내용을 GitHub UI에 복사/붙여넣기 하세요.

## ⚠️ 주의사항

### Q: GITHUB_TOKEN은 어디서 만드나요?
**A**: 만들 필요 없습니다! GitHub Actions가 자동으로 제공합니다.
- `${{ secrets.GITHUB_TOKEN }}`은 각 workflow 실행 시 자동 생성
- 별도 설정이나 Secret 등록 불필요
- 자동으로 해당 repository 접근 권한 포함

### Q: 다른 step에도 추가해야 하나요?
**A**: 아니요! **"Initialize TFLint" step에만** 추가하면 됩니다.
- "Run TFLint" step은 플러그인을 다운로드하지 않으므로 불필요
- 다른 Job (TFSec, Checkov, Trivy)도 불필요

### Q: 보안상 문제는 없나요?
**A**: 전혀 없습니다!
- GITHUB_TOKEN은 해당 workflow에서만 유효
- Repository에 대한 읽기 권한만 필요
- 자동으로 만료되어 재사용 불가능
- GitHub 공식 권장 방법

## ✅ 검증 방법

수정 후 다음 방법으로 확인:

### 1. GitHub Actions 실행
- Push to develop 또는 PR 생성
- Actions 탭에서 "Terraform Tests" 확인

### 2. TFLint Job 확인
- 13개 모든 레이어가 성공하는지 확인
- "Initialize TFLint" step이 모두 ✅인지 확인

### 3. 로그 확인
```
Initialize TFLint
  └─ Installing "aws" plugin...
  └─ Installed "aws" (source: github.com/terraform-linters/tflint-ruleset-aws, version: 0.30.0)
  ✅ Success!
```

## 📚 관련 문서

- `TFLINT_RATE_LIMIT_FIX.md` - Rate Limit 문제 상세 분석
- [GitHub Actions GITHUB_TOKEN](https://docs.github.com/en/actions/security-guides/automatic-token-authentication)
- [GitHub API Rate Limiting](https://docs.github.com/en/rest/overview/resources-in-the-rest-api#rate-limiting)

## 🎯 요약

### 수정 위치:
```
파일: .github/workflows/terraform-tests.yml
위치: Line 107-114
Step: "Initialize TFLint"
```

### 추가 내용:
```yaml
env:
  GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### 효과:
- ✅ Rate Limit: 60 → 1,000회/시간
- ✅ 모든 13개 레이어 안정적으로 처리
- ✅ layers/02-security 에러 해결
- ✅ 추가 비용 없음 (GitHub 자동 제공)
