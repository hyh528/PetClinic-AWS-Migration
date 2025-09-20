# [초보자용] 우리 팀 GitHub 협업 실전 가이드 (v2)

이 문서는 우리 팀원이 GitHub를 사용하여 작업을 진행하는 전체 과정을 단계별로 설명하는 실용 가이드입니다. 아래 예시를 그대로 따라오시면, 우리 프로젝트의 협업 흐름을 쉽게 익힐 수 있습니다.

---

### 📖 시나리오

- **담당자:** 휘권 (Security & Compliance Lead)
- **할 일:** GitHub 이슈 #6으로 등록된 "ECS Task 실행을 위한 IAM 정책 초안 작성" 작업을 진행한다.

---

## 1단계: 내 컴퓨터에 프로젝트 준비하기

### 1.1. 프로젝트 복제 (최초 한 번만)

가장 먼저, GitHub에 있는 우리 프로젝트를 내 컴퓨터로 그대로 복사해와야 합니다.

```bash
# 1. 프로젝트를 저장하고 싶은 폴더로 이동합니다.
# 예: cd C:/Users/maius/Desktop/projects

# 2. git clone 명령어로 원격 저장소를 내 컴퓨터에 복제합니다.
git clone https://github.com/hyh528/PetClinic-AWS-Migration.git

# 3. 방금 생성된 프로젝트 폴더로 이동합니다.
cd PetClinic-AWS-Migration
```

### 1.2. `develop` 브랜치 생성 (PM이 한 번만 실행)

> **Note:** 이 작업은 PM(영현님)이 이미 완료했습니다. 팀원들은 2단계부터 진행하면 됩니다.

```bash
# main 브랜치에서 develop 브랜치를 생성합니다.
git checkout -b develop
# 원격 저장소에 develop 브랜치를 Push하여 팀원들이 공유할 수 있도록 합니다.
git push origin develop
```

---

## 2단계: 새로운 작업 시작하기

이제 이슈 #6에 할당된 작업을 시작하겠습니다.

### 2.1. 내 할 일(이슈) 확인

- GitHub 저장소의 **Issues 탭**으로 가서, 나에게 할당된 **이슈 #6**의 내용을 다시 한번 꼼꼼히 확인합니다.

### 2.2. 최신 코드로 업데이트 (매우 중요!)

- 다른 팀원들의 작업이 이미 `develop` 브랜치에 반영되었을 수 있습니다. 항상 최신 버전의 코드에서 내 작업을 시작해야 충돌을 피할 수 있습니다.

```bash
# 1. 공동 작업실인 develop 브랜치로 이동합니다.
git checkout develop

# 2. 원격 저장소(origin)의 최신 develop 브랜치 내용을 내 컴퓨터로 가져옵니다.
git pull origin develop
```

### 2.3. 내 작업용 브랜치 만들기

- 이제 이슈 #6 작업을 위한 나만의 작업 공간(브랜치)을 만듭니다.

```bash
# 브랜치 이름은 [타입/작업-요약] 규칙에 따라 만듭니다.
# 'IAM 정책 초안 작성'은 보안(security) 작업입니다.
git checkout -b security/draft-ecs-task-policy
```

- 이제 `security/draft-ecs-task-policy` 라는 나만의 브랜치가 만들어졌고, 현재 이 브랜치에서 작업 중인 상태입니다.

---

## 3단계: 코드 작업 및 저장하기 (Commit)

### 3.1. 파일 생성 및 수정

- `docs/security/` 폴더를 새로 만들고, 그 안에 `ecs-task-role-policy.md` 파일을 생성하여 IAM 정책 초안(JSON 형식)을 작성합니다.

### 3.2. 작업 내용 저장 (Commit)

- 내가 한 작업을 의미 있는 단위로 쪼개서 저장(커밋)합니다. 커밋 메시지는 `태그: 제목` 규칙을 따릅니다.

```bash
# 1. 내가 변경한 모든 파일들을 스테이징 영역에 추가합니다.
git add .

# 2. 커밋 메시지와 함께 저장합니다.
git commit -m "Security: Draft IAM policy for ECS Task Role"
```

---

## 4단계: GitHub에 내 작업 공유하기 (Push)

내 컴퓨터에만 저장되어 있던 작업 내용을 동료들이 볼 수 있도록 GitHub 원격 저장소에 올립니다.

```bash
# 내가 작업한 security/draft-ecs-task-policy 브랜치를 원격 저장소(origin)에 올립니다.
git push origin security/draft-ecs-task-policy
```

---

## 5단계: Pull Request(PR) 요청하기

이제 내 작업을 `develop` 브랜치에 합쳐달라고 공식적으로 요청할 차례입니다.

1.  **GitHub 저장소**에 접속하면, 방금 Push한 브랜치에 대해 **"Compare & pull request"** 버튼이 노란색으로 표시됩니다. 이 버튼을 클릭합니다.
2.  PR 생성 화면이 나타나면, 우리가 만든 **PR 템플릿**이 자동으로 적용되어 있습니다. 템플릿의 각 항목을 꼼꼼히 채워줍니다.
    - **PR 제목:** `[Security] ECS Task 실행을 위한 IAM 정책 초안 작성 (#6)` 라고 작성합니다. (`(#6)`를 꼭 포함해야 이슈와 자동 연결됩니다.)
    - **작업 내용, 체크리스트:** 템플릿에 맞춰 내가 한 일을 상세히 적습니다.
    - **Reviewers:** PM(영현) 또는 다른 팀원 1명을 리뷰어로 지정합니다.
3.  **"Create pull request"** 버튼을 눌러 PR 생성을 완료합니다.

---

## 6단계: 코드 리뷰 반영 및 작업 마무리 (Merge)

1.  리뷰어가 내 코드를 보고 의견(Comment)을 남기거나 변경을 요청할 수 있습니다.
2.  요청 사항이 있다면, 동료와 충분히 소통한 후 내 컴퓨터의 `security/draft-ecs-task-policy` 브랜치에서 **코드를 다시 수정하고 커밋, 푸시**합니다. (PR에 자동으로 반영됩니다.)
3.  리뷰어에게 **Approve(승인)** 를 받으면, PR 페이지의 **"Merge pull request"** 버튼을 눌러 내 작업을 `develop` 브랜치에 최종적으로 합칩니다.
4.  Merge가 완료된 후 나타나는 **"Delete branch"** 버튼을 눌러, 이제 역할이 끝난 `security/draft-ecs-task-policy` 브랜치를 깨끗하게 삭제합니다.

**이것으로 하나의 작업이 모두 끝났습니다! 이제 다시 2단계로 돌아가 다음 작업을 시작하면 됩니다.**
