# Terraform ECR 전환 작업 요약 (2025-10-10)

## 목표
- `customers`, `vets`, `visits` 마이크로서비스를 Terraform을 사용하여 AWS ECS로 단계적으로 전환하는 것을 목표로 함.
- 사용자가 초심자이므로 각 단계를 상세히 안내하며 진행.

## 현재까지 진행 상황

### 1. ECR(Elastic Container Registry) 모듈 생성
- 각 서비스의 Docker 이미지를 저장할 ECR 리포지토리 생성을 위해 Terraform 모듈을 만들기로 함.
- **경로**: `terraform/modules/ecr/`
- **파일**:
    - `main.tf`: `aws_ecr_repository` 리소스를 `for_each`를 사용해 동적으로 생성하는 코드 작성.
    - `variables.tf`: 리포지토리 이름을 받을 `repository_names` (list)와 `tags` (map) 변수 정의.
    - `outputs.tf`: 생성된 리포지토리의 URL을 출력하는 `repository_urls` 정의.

### 2. `dev` 환경에서 ECR 모듈 사용
- 개발 환경(`dev`)에서 위에서 만든 `ecr` 모듈을 사용하도록 설정.
- 사용자가 `terraform/envs/dev/application/main.tf` 파일 내부에 `ecr` 모듈 호출 코드를 추가함.
- **전달된 값**:
    - `repository_names`: `customers-service`, `vets-service`, `visits-service`
    - `tags`: `Environment = "dev"`, `Project = "PetClinic"`

### 3. `terraform init` 오류 및 원인 분석
- **문제**: 사용자가 `terraform/envs/dev` 폴더에서 `terraform init` 실행 후 "empty directory" 오류 메시지 확인.
- **원인**: Terraform은 명령어를 실행하는 위치의 `.tf` 파일만 읽는데, 실제 코드는 하위 폴더인 `application/` 안에 있었기 때문.

## 주요 논의 및 결정사항

- **`default` 값의 역할**: Terraform 변수에서 `default` 값이 하는 역할(필수 -> 선택)과 동작 방식에 대해 예시를 통해 설명함.
- **Terraform vs Docker 역할**: Terraform은 '인프라(ECR 리포지토리)'를 만들고, Docker는 '애플리케이션(이미지)'을 빌드하고 푸시하는 역할임을 명확히 함.
- **파일 구조**: 코드 관리의 편의성을 위해 `ecr` 모듈 코드를 `terraform/envs/dev/ecr.tf` 파일로 분리하는 방안을 제안함.

## 다음 단계
- 사용자가 파일 구조를 어떻게 가져갈지(분리 vs 현재 유지) 결정하는 것을 기다리고 있음.
