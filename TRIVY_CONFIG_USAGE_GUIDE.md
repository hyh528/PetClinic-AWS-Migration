# Trivy Config File 사용 가이드

## 📋 현재 상태

### ✅ Push 완료된 파일들:
- `terraform/.trivyignore` - 취약점 예외 설정
- `terraform/trivy.yaml` - Trivy 설정 파일
- `TRIVY_INTEGRATION_GUIDE.md` - Trivy 통합 가이드

### ⚠️ 수동 업데이트 필요:
- `.github/workflows/terraform-tests.yml` - Workflow 파일 (권한 문제로 push 불가)

## 🔧 `trivy.yaml` 사용 방법

### 문제점
현재 workflow는 `trivy.yaml` 파일을 **참조하지 않습니다**:

```yaml
# 현재 상태 (trivy.yaml 사용 안함)
- name: Run Trivy IaC scan
  uses: aquasecurity/trivy-action@master
  with:
    scan-type: 'config'
    scan-ref: 'terraform/'
    format: 'sarif'
    # ⚠️ trivy-config 파라미터가 없음!
```

### 해결 방법

**Option 1: GitHub 웹 UI에서 직접 수정 (권장)**

1. GitHub 저장소로 이동: https://github.com/hyh528/PetClinic-AWS-Migration
2. `.github/workflows/terraform-tests.yml` 파일 열기
3. 아래 두 곳에 `trivy-config` 라인 추가:

#### 수정 위치 1: SARIF 스캔 (Line 224-232)
```yaml
      - name: Run Trivy IaC scan
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'config'
          scan-ref: 'terraform/'
          trivy-config: 'terraform/trivy.yaml'  # 👈 이 줄 추가!
          format: 'sarif'
          output: 'trivy-results.sarif'
          severity: 'CRITICAL,HIGH,MEDIUM'
          exit-code: '0'
```

#### 수정 위치 2: Table 출력 (Line 241-248)
```yaml
      - name: Run Trivy IaC scan (table output)
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'config'
          scan-ref: 'terraform/'
          trivy-config: 'terraform/trivy.yaml'  # 👈 이 줄 추가!
          format: 'table'
          severity: 'CRITICAL,HIGH,MEDIUM'
          exit-code: '0'
```

4. "Commit changes" 버튼으로 직접 커밋

**Option 2: 백업 파일 사용**

로컬에 `terraform-tests-with-trivy-config.yml` 파일이 생성되어 있습니다.
이 파일의 내용을 복사해서 GitHub UI에 붙여넣으세요.

## 📄 `trivy.yaml` 파일 구조

```yaml
# Trivy Configuration for Terraform IaC Scanning

scan:
  file-patterns:
    - "*.tf"
    - "*.tfvars"
  
  security-checks:
    - config      # IaC 설정 스캔
    - secret      # 하드코딩된 시크릿 감지

severity:
  - CRITICAL
  - HIGH
  - MEDIUM

vulnerability:
  type:
    - os
    - library

format: table
ignorefile: .trivyignore  # terraform/.trivyignore 파일 참조

cache:
  backend: fs
  ttl: 24h

timeout: 5m
exit-code: 0  # 취약점 발견해도 CI/CD 계속 진행
```

## 🎯 `trivy.yaml` 사용 효과

### Before (trivy.yaml 없을 때):
```yaml
# Workflow에서 모든 설정을 직접 지정
with:
  scan-type: 'config'
  scan-ref: 'terraform/'
  format: 'sarif'
  severity: 'CRITICAL,HIGH,MEDIUM'
  exit-code: '0'
  # 캐시, 타임아웃, file-patterns 등은 기본값 사용
```

### After (trivy.yaml 사용 시):
```yaml
# Workflow는 간결하게, 세부 설정은 trivy.yaml에서 관리
with:
  scan-type: 'config'
  scan-ref: 'terraform/'
  trivy-config: 'terraform/trivy.yaml'  # 모든 설정 참조
  format: 'sarif'  # format만 override
```

## ⚙️ 설정 우선순위

Trivy는 다음 순서로 설정을 적용합니다:

1. **Workflow 파라미터** (최우선) - `format`, `severity` 등
2. **trivy.yaml 파일** (중간) - 파일에 명시된 설정
3. **기본값** (최후) - Trivy 내장 기본값

따라서 workflow에 `severity: 'CRITICAL,HIGH,MEDIUM'`가 있으면,
`trivy.yaml`의 severity 설정을 **override** 합니다.

## 🔍 실제 동작 확인

### 현재 (trivy-config 없음):
- `trivy.yaml` 파일이 push되었지만 **사용되지 않음**
- Workflow가 하드코딩된 파라미터만 사용
- `.trivyignore`도 무시됨 (ignorefile 설정 적용 안됨)

### 수정 후 (trivy-config 추가):
- `trivy.yaml`의 모든 설정이 적용됨
- `.trivyignore` 파일 자동 인식
- 캐시, 타임아웃, file-patterns 등 세부 설정 사용
- 중앙 집중식 설정 관리 가능

## 🛠️ 설정 커스터마이징 예시

### 예시 1: 개발 환경에서 LOW 심각도도 스캔
```yaml
# terraform/trivy.yaml 수정
severity:
  - CRITICAL
  - HIGH
  - MEDIUM
  - LOW  # 추가
```

### 예시 2: 특정 취약점 무시
```bash
# terraform/.trivyignore 수정
AVD-AWS-0086  # S3 버킷 로깅 비활성화 (개발 환경 허용)
AVD-AWS-0132  # ECS 태스크 정의 권한 (테스트 환경)
```

### 예시 3: Secret 스캔 강화
```yaml
# terraform/trivy.yaml 수정
scan:
  security-checks:
    - config
    - secret
    - license  # 라이센스 체크 추가
```

## 📊 Git Push 자동화 여부

### ✅ 자동으로 적용되는 파일들:
```bash
terraform/.trivyignore    # Git push 하면 즉시 사용 가능
terraform/trivy.yaml      # Git push 하면 즉시 사용 가능
```

**단, workflow에 `trivy-config` 파라미터가 있어야 합니다!**

### ❌ 수동 업데이트 필요:
```bash
.github/workflows/terraform-tests.yml  # GitHub App 권한 제약
```

## 🚀 다음 단계

1. **GitHub 웹 UI로 이동**
   ```
   https://github.com/hyh528/PetClinic-AWS-Migration/blob/develop/.github/workflows/terraform-tests.yml
   ```

2. **Edit 버튼 클릭**

3. **두 곳에 `trivy-config` 추가**
   - Line 228: SARIF 스캔
   - Line 246: Table 출력

4. **커밋 메시지 작성**
   ```
   feat: Integrate trivy.yaml config file in Trivy scanning
   
   - Add trivy-config parameter to reference terraform/trivy.yaml
   - Enable centralized Trivy settings management
   ```

5. **Commit changes**

6. **GitHub Actions에서 테스트**
   - Push to develop 또는 PR 생성
   - Actions 탭에서 "Terraform Tests" 워크플로우 확인

## ✅ 확인 체크리스트

- [ ] `terraform/trivy.yaml` push 완료 (✅ 완료)
- [ ] `terraform/.trivyignore` push 완료 (✅ 완료)
- [ ] `TRIVY_INTEGRATION_GUIDE.md` push 완료 (✅ 완료)
- [ ] Workflow에 `trivy-config` 파라미터 추가 (⏳ 수동 작업 필요)
- [ ] GitHub Actions 테스트 실행 (⏳ 위 작업 후)
- [ ] Security 탭에서 Trivy 결과 확인 (⏳ 테스트 후)

## 💡 팁

- **우선**: `trivy-config` 없어도 Trivy는 동작합니다. 단지 기본 설정만 사용할 뿐입니다.
- **권장**: `trivy-config`를 추가하면 세부 설정을 파일로 관리할 수 있어 유지보수가 편합니다.
- **나중에**: 프로젝트가 커지면 환경별로 다른 trivy 설정 파일을 사용할 수 있습니다.
  ```yaml
  trivy-config: 'terraform/trivy-prod.yaml'  # 프로덕션용
  trivy-config: 'terraform/trivy-dev.yaml'   # 개발용
  ```

## 📚 참고 문서

- [Trivy GitHub Action 문서](https://github.com/aquasecurity/trivy-action)
- [Trivy Configuration 가이드](https://aquasecurity.github.io/trivy/latest/docs/configuration/)
- 프로젝트 내 `TRIVY_INTEGRATION_GUIDE.md` - 상세한 Trivy 사용법
