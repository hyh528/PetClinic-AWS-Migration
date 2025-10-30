# Terraform ECS 작업 역할에 KMS 접근 권한 활성화

이 문서는 ECS 작업 실행 시 `AccessDeniedException: Access to KMS is not allowed` 오류가 발생하는 문제를 해결하는 두 가지 방안을 모두 기록합니다.

## 1. 문제 원인

- **오류 메시지**: `ResourceInitializationError: ... AccessDeniedException: Access to KMS is not allowed`
- **원인**: ECS 작업(Task)이 시작될 때 AWS Secrets Manager에서 데이터베이스 암호 등의 보안 정보를 가져와야 합니다. 이 정보는 KMS 키로 암호화되어 있는데, ECS 작업의 실행 역할(`ecs_task_execution_role`)에 이 KMS 키를 복호화(`kms:Decrypt`)할 권한이 없어서 발생하는 문제입니다.

---

## 2. 해결 방안 요약

두 가지 해결 방안이 있습니다. 각 방안은 장단점이 있어 상황에 맞게 선택할 수 있습니다.

### 방안 1: 빠른 해결 (Application 레이어 직접 수정)
- **설명**: `application` 레이어에 직접 IAM 정책을 만들어 역할에 연결합니다. 가장 간단하고 빠르게 문제를 해결할 수 있습니다.
- **장점**: 수정 파일이 하나뿐이라 즉시 적용이 가능합니다.
- **단점**: IAM 정책 코드가 `application` 레이어에 존재하게 되어, 중앙에서 IAM을 관리하는 원칙에는 위배될 수 있습니다.

### 방안 2: 모듈식 해결 (IAM 모듈 활용)
- **설명**: 보안팀의 역할 분담을 고려하여, IAM 정책을 `iam` 모듈에서 중앙 관리하고 `application` 레이어에서는 이 정책을 가져와 사용합니다.
- **장점**: 역할과 책임이 명확히 분리되어 코드 구조가 깔끔해지고 보안 관리가 용이합니다.
- **단점**: 여러 파일과 레이어를 수정해야 하므로 과정이 다소 복잡합니다.

---

## 3. 상세 코드: 방안 1 (빠른 해결)

`application` 레이어의 `cluster.tf` 파일 하나만 수정하면 됩니다.

**파일 경로**: `terraform/envs/dev/application/cluster.tf`

파일 맨 아래에 아래 코드 블록을 추가합니다. 이 코드는 필요한 권한을 가진 정책과, 그 정책을 `ecs_task_execution_role`에 연결하는 리소스를 생성합니다.

```terraform
# terraform/envs/dev/application/cluster.tf 파일 맨 아래에 추가

# KMS and Secrets Manager Decrypt Policy
resource "aws_iam_policy" "ecs_secrets_policy" {
  name        = "petclinic-ecs-secrets-policy"
  description = "Allow ECS tasks to decrypt secrets from Secrets Manager"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "secretsmanager:GetSecretValue",
          "kms:Decrypt"
        ],
        # For production, it's highly recommended to restrict this to the specific
        # secret ARN and KMS key ARN.
        Resource = "*"
      }
    ]
  })
}

# Attach the new policy to the ECS Task Execution Role
resource "aws_iam_role_policy_attachment" "ecs_secrets_policy_attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = aws_iam_policy.ecs_secrets_policy.arn
}
```

**적용 방법**: `terraform/envs/dev/application` 디렉토리에서 `terraform apply`를 실행합니다.

---

## 4. 상세 코드: 방안 2 (모듈식 해결)

`iam` 모듈, `security` 환경, `application` 환경 총 3곳을 수정해야 합니다.

### 4.1. `iam` 모듈 수정 (`terraform/modules/iam/`)

중앙에서 관리할 IAM 정책을 생성하고, 이 정책의 ARN을 모듈 외부에서 사용할 수 있도록 `output`으로 노출시킵니다.

**1) `main.tf` 파일에 정책 리소스 추가**
```terraform
# terraform/modules/iam/main.tf 파일 맨 아래에 추가

resource "aws_iam_policy" "ecs_secrets_policy" {
  name        = "petclinic-ecs-secrets-policy"
  description = "Allow ECS tasks to access specific secrets and KMS keys"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "secretsmanager:GetSecretValue",
          "kms:Decrypt"
        ],
        Resource = "*"
      }
    ]
  })
}
```

**2) `outputs.tf` 파일에 정책 ARN 출력 추가**
```terraform
# terraform/modules/iam/outputs.tf 파일 맨 아래에 추가

output "ecs_secrets_policy_arn" {
  description = "ARN of the policy for ECS to access secrets"
  value       = aws_iam_policy.ecs_secrets_policy.arn
}
```

### 4.2. `security` 환경 수정 (`terraform/envs/dev/security/`)

`iam` 모듈을 활성화하여 위에서 정의한 정책 리소스가 실제로 생성되도록 하고, 그 결과(ARN)를 `security` 레이어의 `output`으로 외부에 노출시킵니다.

**1) `main.tf` 파일에서 `iam` 모듈 활성화**
주석 처리된 `module "iam"` 블록의 주석을 제거합니다.

```terraform
# terraform/envs/dev/security/main.tf

# ... (상략) ...
# 아래 블록의 주석을 제거하여 활성화합니다.
module "iam" {
  source = "../../../modules/iam"

  project_name = "petclinic"
  team_members = ["yeonghyeon", "seokgyeom", "junje", "hwigwon"]
}
# ... (하략) ...
```

**2) `outputs.tf` 파일에 `iam` 모듈의 출력값 추가**
```terraform
# terraform/envs/dev/security/outputs.tf 파일 맨 아래에 추가

output "ecs_secrets_policy_arn" {
  description = "ARN of the policy for ECS to access secrets"
  value       = module.iam.ecs_secrets_policy_arn
}
```

### 4.3. `application` 환경 수정 (`terraform/envs/dev/application/`)

`security` 레이어에서 노출한 정책 ARN을 원격 상태(remote state)로 읽어와, `application` 레이어에 있는 `ecs_task_execution_role`에 연결합니다.

**1) `cluster.tf` 파일에 정책 연결(attachment) 리소스 추가**
```terraform
# terraform/envs/dev/application/cluster.tf 파일 맨 아래에 추가

# security 레이어에서 생성한 KMS/Secret 접근 정책을 ECS 작업 실행 역할에 연결
resource "aws_iam_role_policy_attachment" "ecs_secrets_policy_attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = data.terraform_remote_state.security.outputs.ecs_secrets_policy_arn
}
```

**적용 순서**:
1.  **`security` 레이어 적용**: `terraform/envs/dev/security` 디렉토리로 이동하여 `terraform apply`를 실행합니다.
2.  **`application` 레이어 적용**: `terraform/envs/dev/application` 디렉토리로 이동하여 `terraform apply`를 실행합니다.