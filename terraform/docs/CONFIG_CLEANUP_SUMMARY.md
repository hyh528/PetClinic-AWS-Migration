# 설정 파일 중복 제거 요약

## 변경사항

### 제거된 파일들
- `terraform/.checkov.yaml` - GitHub Actions에서 직접 실행하므로 중복
- `terraform/.tfsec.yml` - GitHub Actions에서 직접 실행하므로 중복

### 업데이트된 파일들

#### 1. `.github/workflows/terraform-infrastructure.yml`
- checkov 실행 시 필요한 설정을 직접 지정
- 개발 환경에서 허용되는 체크들을 skip_check 파라미터로 설정

#### 2. `terraform/docs/TESTING_GUIDE.md`
- checkov 로컬 실행 가이드를 GitHub Actions 자동 실행으로 변경
- 테스트 가이드에서 중복 제거된 구조 반영

#### 3. `terraform/README.md`
- 보안 스캔 섹션을 GitHub Actions 자동 실행 방식으로 업데이트
- 로컬에서는 기본 검증만 실행하도록 가이드 변경

## 장점

### 1. 구조 단순화
- 설정 파일 중복 제거로 프로젝트 구조 간소화
- 유지보수해야 할 설정 파일 수 감소

### 2. 일관성 향상
- GitHub Actions에서 중앙 집중식 설정 관리
- 모든 개발자가 동일한 보안 검증 규칙 적용

### 3. 유지보수성 개선
- 보안 규칙 변경 시 GitHub Actions 워크플로우만 수정하면 됨
- 설정 파일 동기화 문제 해결

## 사용법

### PR 생성 시
- 자동으로 checkov와 tflint가 실행됨
- 설정은 GitHub Actions 워크플로우에서 관리

### 로컬 개발 시
```bash
# 기본 검증만 실행
terraform fmt -check -recursive
terraform validate

# 보안 스캔은 PR 생성 시 자동 실행됨
```

### 보안 규칙 변경 시
1. `.github/workflows/terraform-infrastructure.yml` 파일 수정
2. `skip_check` 파라미터에서 허용할 체크들 조정
3. 변경사항을 PR로 제출하여 팀 검토

## 결론

이번 중복 제거를 통해:
- 프로젝트 구조가 더 깔끔해졌습니다
- 설정 관리가 중앙 집중화되었습니다
- 개발자 경험이 개선되었습니다 (로컬에서 복잡한 설정 불필요)
- CI/CD 파이프라인에서 일관된 보안 검증이 보장됩니다