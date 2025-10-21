# ECS 추가 권한 설정 및 오류 해결 요약

이 문서는 ECS 서비스 시작 시 `ResourceInitializationError`와 함께 발생하는 여러 권한 문제를 진단하고 해결하는 과정을 종합적으로 기록합니다.

---

## 문제 요약

ECS 작업이 시작되지 못하고 아래와 같은 권한 오류들이 순차적으로 발생했습니다.

1.  **KMS 오류**: `AccessDeniedException: Access to KMS is not allowed`
2.  **SSM (VPC 엔드포인트) 오류**: `...no VPC endpoint policy allows the ssm:GetParameters action`
3.  **ECR (VPC 엔드포인트) 오류**: `...no VPC endpoint policy allows the ecr:GetAuthorizationToken action`
4.  **SSM (IAM 역할) 오류**: `...no identity-based policy allows the ssm:GetParameters action`
5.  **IAM 정책 연결 대상 오류**: `apply`는 성공했으나, 정책이 엉뚱한 역할(`...-task-role`)에 연결됨.

## 최종 해결 방안 종합

각 문제의 원인을 해결하기 위한 최종 코드 수정 내역입니다.

### 1. IAM 역할 권한 문제 해결 (KMS, SSM)

- **원인**: ECS 실행 역할(`...-execution-role`)에 KMS 복호화, SSM 파라미터 읽기 권한이 없음.
- **해결**: `iam` 모듈의 중앙 관리 정책에 필요한 모든 권한(`secretsmanager:GetSecretValue`, `kms:Decrypt`, `ssm:GetParameters`)을 추가합니다.

#### 📝 **수정 파일: `terraform/modules/iam/main.tf`**

```terraform
# resource "aws_iam_policy" "ecs_secrets_policy" 블록을 찾아 아래와 같이 수정

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
          "kms:Decrypt",
          "ssm:GetParameters" # SSM 읽기 권한 추가
        ],
        Resource = "*"
      }
    ]
  })
}
```

### 2. VPC 엔드포인트 정책 문제 해결 (SSM, ECR)

- **원인**: VPC 엔드포인트의 정책이 너무 제한적이어서 SSM과 ECR로의 API 호출을 차단함.
- **해결**: `endpoint` 모듈에 각 서비스(SSM, ECR)를 위한 전용 정책을 만들고, 필요한 액션을 명시적으로 허용합니다.

#### 📝 **수정 파일: `terraform/modules/endpoint/main.tf`**

**1) SSM, ECR 전용 정책 `locals` 블록 추가**
```hcl
# 파일 상단 locals 블록들이 모여있는 곳에 추가

# SSM 전용 정책
locals {
  ssm_vpc_endpoint_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = "*",
        Action    = ["ssm:GetParameters", "ssm:GetParameter", "ssm:DescribeParameters"],
        Resource  = "*",
        Condition = { StringEquals = { "aws:PrincipalVpc" = var.vpc_id } }
      }
    ]
  })
}

# ECR 전용 정책
locals {
  ecr_vpc_endpoint_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = "*",
        Action    = "ecr:*",
        Resource  = "*",
        Condition = { StringEquals = { "aws:PrincipalVpc" = var.vpc_id } }
      }
    ]
  })
}
```

**2) 각 엔드포인트 리소스가 전용 정책을 사용하도록 `policy` 인자 수정**
```hcl
# "ssm" 엔드포인트 리소스 수정
resource "aws_vpc_endpoint" "ssm" {
  # ...
  policy = local.ssm_vpc_endpoint_policy
  # ...
}

# "ecr_api" 엔드포인트 리소스 수정
resource "aws_vpc_endpoint" "ecr_api" {
  # ...
  policy = local.ecr_vpc_endpoint_policy
  # ...
}

# "ecr_dkr" 엔드포인트 리소스 수정
resource "aws_vpc_endpoint" "ecr_dkr" {
  # ...
  policy = local.ecr_vpc_endpoint_policy
  # ...
}
```

### 3. IAM 정책 연결 대상 오류 해결

- **원인**: `iam` 모듈에서 생성된 정책들이 `...-task-role`에 잘못 연결됨.
- **해결**: `iam` 모듈 내 `aws_iam_role_policy_attachment` 리소스의 `role` 속성값을 올바른 실행 역할(`petclinic-ecs-task-execution-role`) 이름으로 수정합니다.

#### 📝 **수정 파일: `terraform/modules/iam/main.tf`**

```terraform
# 최근 추가된 것으로 보이는 attachment 리소스들을 찾아 role 값을 수정

resource "aws_iam_role_policy_attachment" "ecs_secrets_policy_attachment" {
  policy_arn = aws_iam_policy.ecs_secrets_policy.arn
  role       = "petclinic-ecs-task-execution-role" # <--- 올바른 실행 역할로 수정
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  role       = "petclinic-ecs-task-execution-role" # <--- 올바른 실행 역할로 수정
}
```

---

## 최종 적용 순서

위 모든 코드 수정이 완료된 후, 터미널에서 아래 순서대로 `apply`를 실행하여 모든 변경사항을 AWS에 최종적으로 반영합니다.

1.  **`security` 레이어 적용 (IAM 정책, 엔드포인트 정책 변경)**
    ```shell
    cd terraform/envs/dev/security
    terraform apply
    ```

2.  **`application` 레이어 적용 (역할-정책 연결 관계 확인)**
    ```shell
    cd ../application
    terraform apply
    ```
