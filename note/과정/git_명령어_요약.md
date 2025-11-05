# Git 명령어 요약

이 문서는 자주 사용하는 Git 명령어와 그 기능을 요약합니다.

## 리모트(Remote) 관련 명령어

원격 저장소를 관리하는 명령어입니다.

- **리모트 추가**
  ```bash
  git remote add <리모트_이름> <리포지토리_URL>
  ```
  - 예시: `git remote add pet https://github.com/hyh528/PetClinic-AWS-Migration.git`

- **리모트 목록 확인**
  ```bash
  git remote -v
  ```
  - 설정된 모든 원격 저장소의 이름과 URL을 보여줍니다.

- **리모트 삭제**
  ```bash
  git remote remove <리모트_이름>
  ```
  - 예시: `git remote remove pet`

## 푸시(Push) 관련 명령어

로컬 브랜치의 변경사항을 리모트 저장소로 업로드합니다.

- **기본 푸시 (로컬과 리모트 브랜치 이름이 같을 때)**
  ```bash
  git push <리모트_이름> <브랜치_이름>
  ```
  - 예시: `git push origin main`
  - `git push pet application/ksk-deploy` 와 `git push pet application/ksk-deploy:application/ksk-deploy`는 동일하게 동작합니다.

- **특정 리모트 브랜치로 푸시 (로컬과 리모트 브랜치 이름이 다를 때)**
  ```bash
  git push <리모트_이름> <로컬_브랜치_이름>:<리모트_브랜치_이름>
  ```
  - 예시: `git push ksk application/ksk-deploy:main` (로컬의 `application/ksk-deploy` 브랜치를 `ksk` 리모트의 `main` 브랜치로 푸시)

## 브랜치(Branch) 관련 명령어

브랜치를 생성, 삭제, 관리합니다.

- **로컬 브랜치 확인**
  - 터미널 프롬프트의 경로 옆 괄호 안의 이름이 현재 로컬 브랜치를 나타냅니다.
  - 예시: `.../PetClinic-AWS-Migration (application/ksk-deploy)` -> 현재 브랜치는 `application/ksk-deploy`

- **로컬 브랜치 삭제 (안전)**
  ```bash
  git branch -d <브랜치_이름>
  ```
  - 병합이 완료된 브랜치만 삭제합니다.

- **로컬 브랜치 강제 삭제**
  ```bash
  git branch -D <브랜치_이름>
  ```
  - 병합 여부와 상관없이 강제로 삭제합니다.

- **리모트 브랜치 삭제**
  ```bash
  git push <리모트_이름> --delete <브랜치_이름>
  ```
  - 예시: `git push origin --delete feature/login`
