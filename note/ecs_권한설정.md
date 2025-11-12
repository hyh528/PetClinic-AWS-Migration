# Terraform ECS Task Role 권한 설정 요약

이 문서는 ECS Task Definition에 IAM 역할을 부여하여, 컨테이너 안의 애플리케이션이 AWS Secrets Manager 같은 다른 AWS 서비스에 접근할 수 있도록 권한을 설정하는 과정을 요약합니다.

## 1. 목표

ECS 컨테이너에서 실행되는 Spring Boot 애플리케이션이 AWS SDK를 통해 **Secrets Manager**에 저장된 데이터베이스 비밀번호를 안전하게 읽어올 수 있도록 권한을 부여합니다.

## 2. 문제점 진단

최초 분석 결과, `terraform/modules/ecs/main.tf` 파일의 `aws_ecs_task_definition` 리소스에 `task_role_arn` 속성이 누락되어 있었습니다.

- `execution_role_arn`: ECS 에이전트가 ECR에서 이미지를 가져오거나 CloudWatch에 로그를 보낼 때 사용하는 역할. **(이미 설정됨)**
- `task_role_arn`: 컨테이너 안의 **애플리케이션 자체**가 다른 AWS 서비스에 접근할 때 사용하는 역할. **(누락됨)**

이 `task_role_arn`이 없으면 애플리케이션은 AWS API 호출 시 권한 부족(Access Denied) 오류를 겪게 됩니다.

---

## 3. 해결 과정

권한 설정을 위해 아래 3단계에 걸쳐 코드를 수정했습니다.

### 1단계: `ecs` 모듈 수정

`ecs` 모듈이 `task_role_arn`을 입력받아 사용할 수 있도록 구조를 변경했습니다.

- **`terraform/modules/ecs/variables.tf`**: `task_role_arn` 변수 추가
  ```terraform
  variable "task_role_arn" {
    description = "ECS Task에 할당할 IAM 역할의 ARN"
    type        = string
    default     = null
  }
  ```

- **`terraform/modules/ecs/main.tf`**: `aws_ecs_task_definition` 리소스에 `task_role_arn` 속성 추가
  ```terraform
  resource "aws_ecs_task_definition" "service" {
    # ... (family, network_mode 등) ...
    execution_role_arn       = var.ecs_task_execution_role_arn
    task_role_arn            = var.task_role_arn # 이 부분이 추가됨
  
    container_definitions = jsonencode([
      # ...
    ])
  }
  ```

### 2단계: `security` 레이어 수정 (필요 시)

`security` 레이어 담당자가 ECS Task를 위한 IAM 역할을 생성하고, 그 ARN을 출력(output)으로 제공해야 합니다. 만약 이 작업이 되어있지 않다면 아래와 같이 코드를 추가해야 합니다.

- **`terraform/envs/dev/security/main.tf`**: Secrets Manager 접근 권한을 가진 IAM 역할 생성 (예시)
  ```terraform
  # 예시: ECS Task를 위한 IAM 역할 생성
  resource "aws_iam_role" "ecs_task_role" {
    name = "petclinic-ecs-task-role"
    assume_role_policy = jsonencode({
      Version   = "2012-10-17",
      Statement = [{
        Action    = "sts:AssumeRole",
        Effect    = "Allow",
        Principal = { Service = "ecs-tasks.amazonaws.com" }
      }]
    })
  }

  # 예시: 위에서 만든 역할에 Secrets Manager 읽기 권한 정책 연결
  resource "aws_iam_role_policy_attachment" "ecs_task_secrets_manager" {
    role       = aws_iam_role.ecs_task_role.name
    # 실제로는 더 세분화된 정책을 만들거나 AWS 관리형 정책(SecretsManagerReadWrite)을 사용할 수 있습니다.
    policy_arn = "arn:aws:iam::aws:policy/SecretsManagerReadWrite" 
  }
  ```

- **`terraform/envs/dev/security/outputs.tf`**: 생성된 역할의 ARN을 출력으로 추가
  ```terraform
  output "ecs_task_role_arn" {
    description = "ECS Task가 Secrets Manager에 접근하는 데 사용할 IAM 역할의 ARN"
    value       = aws_iam_role.ecs_task_role.arn
  }
  ```

### 3단계: `application` 레이어 수정

`application` 레이어에서 `security` 레이어의 출력값을 가져와 `ecs` 모듈에 전달하도록 수정했습니다.

- **`terraform/envs/dev/application/ecs.tf`**: `module "ecs"` 호출부에 `task_role_arn` 파라미터 추가
  ```terraform
  module "ecs" {
    for_each = local.ecs_services
    source   = "../../../modules/ecs"
  
    # --- 공유 리소스 값 전달 ---
    # ...
    ecs_task_execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
    task_role_arn               = data.terraform_remote_state.security.outputs.ecs_task_role_arn # 이 부분이 추가됨
    listener_arn                = aws_lb_listener.http.arn
  
    # --- 서비스별 값 전달 ---
    # ...
  }
  ```

---

## 4. 주요 Q&A

#### Q: `security` 레이어는 다른 담당자가 관리합니다. 그쪽에서 이미 역할을 만들었다면 2단계 작업이 필요 없나요?
**A:** 네, 맞습니다. 만약 `security` 담당자가 이미 필요한 IAM 역할을 만들고 `ecs_task_role_arn`이라는 이름으로 출력(output)까지 완료했다면, `application` 레이어에서는 해당 원격 상태(remote state)를 읽어 사용하기만 하면 되므로 2단계 작업은 필요 없습니다. 이번 수정은 그 경우를 가정하고 3단계 작업을 진행한 것입니다.

#### Q: `terraform plan` 실행 시 `ecs_task_role_arn`을 찾을 수 없다는 오류가 나면 어떻게 해야 하나요?
**A:** 해당 오류는 `security` 레이어의 원격 상태에 `ecs_task_role_arn` 출력이 없다는 의미입니다. 이 경우, `security` 담당자에게 연락하여 2단계에서 설명한 IAM 역할과 출력(output)을 생성하고 `terraform apply`를 해달라고 요청해야 합니다.

---

## 5. 최종 확인 방법

1.  `terraform/envs/dev/application` 디렉터리로 이동합니다.
2.  `terraform plan` 명령어를 실행합니다.
3.  `plan`이 오류 없이 성공적으로 실행되면, `aws_ecs_task_definition` 리소스의 `task_role_arn` 속성이 올바르게 설정되었는지 확인할 수 있습니다.
