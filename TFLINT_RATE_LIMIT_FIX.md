# TFLint GitHub API Rate Limit 해결 가이드

## 🔴 문제 상황

### 에러 메시지:
```
Failed to install a plugin; Failed to fetch GitHub releases: 
GET https://api.github.com/repos/terraform-linters/tflint-ruleset-aws/releases/tags/v0.30.0: 
403 API rate limit exceeded for 20.161.28.177
```

### 발생 레이어:
- `layers/02-security`에서 실패 (3번째 레이어)

## 🔍 원인 분석

### 왜 Security 레이어에서만 실패했나?

**Matrix 병렬 실행 + GitHub API Rate Limit 때문입니다.**

```yaml
# TFLint Job Matrix 실행 순서
matrix:
  layer:
    - bootstrap-oregon      # Job 1: ✅ API 호출 성공
    - layers/01-network     # Job 2: ✅ API 호출 성공
    - layers/02-security    # Job 3: ❌ RATE LIMIT!
    - layers/03-database
    # ... 나머지 10개 레이어
```

### 실행 흐름:

```
┌─────────────────────────────────────────────────────────┐
│  각 Matrix Job마다 독립적으로 실행:                    │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  1. Checkout code                                       │
│  2. Setup TFLint                                        │
│  3. Initialize TFLint                                   │
│     └─ tflint --init                                    │
│        └─ AWS Plugin 다운로드 시도                     │
│           └─ GitHub API 호출 👈 여기서 Rate Limit!     │
│              GET /repos/.../releases/tags/v0.30.0       │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### GitHub API Rate Limit:

| 인증 방식 | 시간당 요청 제한 | 13개 레이어 처리 |
|-----------|------------------|------------------|
| **익명 (비인증)** | 60회 | ❌ 불가능 (3번째에서 실패) |
| **GITHUB_TOKEN 사용** | 1,000회 | ✅ 가능 (여유 있음) |
| **Personal Access Token** | 5,000회 | ✅ 가능 (충분함) |

### 왜 Security만 실패했나?

**순서 문제가 아니라 타이밍 문제입니다:**

1. 13개의 Matrix Job이 **거의 동시에** 시작됨
2. 각 Job이 **같은 IP에서** GitHub API 호출
3. GitHub는 **IP 기준**으로 Rate Limit 적용
4. 짧은 시간에 **여러 요청**이 몰림
5. **2-3번째 Job 즈음**에서 Rate Limit 도달
6. Security가 **우연히** 그 타이밍에 걸린 것

> **재실행하면 다른 레이어에서 실패할 수도 있습니다!**

## ✅ 해결 방법

### Solution 1: GITHUB_TOKEN 사용 (권장) ⭐

GitHub Actions에서 자동으로 제공하는 `GITHUB_TOKEN`을 사용합니다.

#### Before (Rate Limit 발생):
```yaml
- name: Initialize TFLint
  working-directory: terraform/${{ matrix.layer }}
  run: |
    tflint --init --config ../.tflint.hcl
```

#### After (Rate Limit 해결):
```yaml
- name: Initialize TFLint
  working-directory: terraform/${{ matrix.layer }}
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}  # 👈 추가!
  run: |
    tflint --init --config ../.tflint.hcl
```

#### 적용 효과:
- ✅ Rate Limit: 60 → 1,000회로 증가
- ✅ 13개 레이어 모두 안정적으로 처리
- ✅ 추가 설정 불필요 (GitHub Actions 자동 제공)

### Solution 2: TFLint Plugin 캐싱

각 Job마다 플러그인을 다운로드하지 않고 캐시를 사용합니다.

```yaml
- name: Cache TFLint plugins
  uses: actions/cache@v3
  with:
    path: ~/.tflint.d/plugins
    key: tflint-${{ hashFiles('terraform/.tflint.hcl') }}

- name: Initialize TFLint
  working-directory: terraform/${{ matrix.layer }}
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
  run: |
    tflint --init --config ../.tflint.hcl
```

#### 장점:
- ✅ API 호출 횟수 감소 (첫 실행 후 캐시 사용)
- ✅ 실행 속도 향상
- ✅ Network 트래픽 절약

#### 단점:
- ⚠️ 캐시 키 관리 필요
- ⚠️ Plugin 업데이트 시 캐시 무효화 필요

### Solution 3: AWS Plugin 버전 최신화

`.tflint.hcl`에서 최신 버전으로 업데이트:

```hcl
# Before
plugin "aws" {
  enabled = true
  version = "0.30.0"  # 구버전
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

# After
plugin "aws" {
  enabled = true
  version = "0.35.0"  # 최신 버전
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}
```

> **참고**: 이 방법만으로는 Rate Limit 문제를 해결할 수 없습니다.
> GITHUB_TOKEN 사용과 함께 적용하세요.

## 🛠️ 적용된 수정 사항

### Modified: `.github/workflows/terraform-tests.yml`

```diff
  - name: Initialize TFLint
    working-directory: terraform/${{ matrix.layer }}
+   env:
+     GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
    run: |
      if [[ "${{ matrix.layer }}" == "bootstrap-oregon" ]]; then
        tflint --init --config ../.tflint.hcl
      else
        tflint --init --config ../../.tflint.hcl
      fi
```

## 📊 Rate Limit 비교

### Before (익명 호출):
```
시간당 60회 제한
├─ bootstrap-oregon    ✅ (1/60)
├─ layers/01-network   ✅ (2/60)
├─ layers/02-security  ❌ (3/60 - Rate Limit!)
└─ ... 나머지 실행 불가
```

### After (GITHUB_TOKEN 사용):
```
시간당 1,000회 제한
├─ bootstrap-oregon    ✅ (1/1000)
├─ layers/01-network   ✅ (2/1000)
├─ layers/02-security  ✅ (3/1000)
├─ layers/03-database  ✅ (4/1000)
├─ ... 모든 레이어 성공
└─ layers/12-notification ✅ (13/1000)

여유 요청 수: 987회 (충분함!)
```

## 🔍 디버깅 팁

### Rate Limit 상태 확인:

```bash
# 현재 Rate Limit 확인 (로컬에서)
curl -H "Authorization: token YOUR_GITHUB_TOKEN" \
  https://api.github.com/rate_limit

# Response:
{
  "resources": {
    "core": {
      "limit": 1000,
      "remaining": 987,
      "reset": 1699564800
    }
  }
}
```

### GitHub Actions에서 확인:

Workflow에 다음 step 추가:

```yaml
- name: Check GitHub API Rate Limit
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
  run: |
    curl -H "Authorization: token $GITHUB_TOKEN" \
         https://api.github.com/rate_limit | jq '.resources.core'
```

## ❓ FAQ

### Q1: GITHUB_TOKEN은 어디서 생성하나요?
**A**: 생성할 필요 없습니다! GitHub Actions가 자동으로 제공합니다.
`${{ secrets.GITHUB_TOKEN }}`만 사용하면 됩니다.

### Q2: 다른 Job에도 적용해야 하나요?
**A**: TFLint Job만 수정하면 됩니다. 다른 Job (TFSec, Checkov, Trivy)은 
GitHub API를 많이 호출하지 않습니다.

### Q3: 왜 매번 다른 레이어에서 실패하나요?
**A**: Matrix Job의 실행 순서가 항상 같지 않고, 여러 Job이 동시에 실행되기 
때문입니다. Rate Limit는 **시간당 총 요청 수**를 제한하므로, 어느 Job이든 
제한에 걸릴 수 있습니다.

### Q4: Personal Access Token (PAT)을 사용해야 하나요?
**A**: 아니요. GITHUB_TOKEN으로 충분합니다. PAT는 다음 경우에만 필요합니다:
- Private repository의 외부 모듈 접근
- Organization 전체 설정 접근
- 더 높은 Rate Limit 필요 (5,000회/시간)

### Q5: 캐싱을 꼭 추가해야 하나요?
**A**: 필수는 아니지만 권장합니다:
- GITHUB_TOKEN만으로도 Rate Limit 문제는 해결됨
- 캐싱 추가 시 **속도 향상** 및 **API 호출 최소화** 효과

## 📚 참고 자료

- [GitHub API Rate Limiting](https://docs.github.com/en/rest/overview/resources-in-the-rest-api#rate-limiting)
- [TFLint Setup Action](https://github.com/terraform-linters/setup-tflint)
- [TFLint AWS Plugin](https://github.com/terraform-linters/tflint-ruleset-aws)
- [GitHub Actions GITHUB_TOKEN](https://docs.github.com/en/actions/security-guides/automatic-token-authentication)

## ✅ 검증 체크리스트

- [x] GITHUB_TOKEN 환경변수 추가
- [ ] Workflow 파일 GitHub UI에서 업데이트 (권한 제약)
- [ ] GitHub Actions 재실행
- [ ] 모든 13개 레이어 TFLint 통과 확인
- [ ] Security 탭에서 결과 확인

## 🚀 다음 단계

1. **GitHub 웹 UI로 이동**:
   ```
   https://github.com/hyh528/PetClinic-AWS-Migration/blob/develop/.github/workflows/terraform-tests.yml
   ```

2. **Edit 버튼 클릭**

3. **Line 107-114 부근 수정**:
   ```yaml
   - name: Initialize TFLint
     working-directory: terraform/${{ matrix.layer }}
     env:
       GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}  # 👈 이 두 줄 추가!
     run: |
       # ... 나머지 동일
   ```

4. **Commit changes**

5. **Workflow 재실행 또는 새 Push로 테스트**

## 💡 요약

- **문제**: TFLint가 GitHub API Rate Limit에 걸림 (60회/시간)
- **원인**: 13개 Matrix Job이 동시에 플러그인 다운로드 시도
- **해결**: `GITHUB_TOKEN` 환경변수 추가 → 1,000회/시간으로 증가
- **결과**: 모든 레이어에서 안정적으로 TFLint 실행 가능
