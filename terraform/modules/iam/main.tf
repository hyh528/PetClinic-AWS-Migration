# CLI 전용 그룹 생성
resource "aws_iam_group" "cli_users" {
  name = "${var.project_name}-cli-users"
}

# AdministratorAccess 정책 연결 (초기 - 나중에 세분화)
resource "aws_iam_group_policy_attachment" "cli_admin" {
  group      = aws_iam_group.cli_users.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# 팀원별 IAM 사용자 생성 (for_each로 일반화)
resource "aws_iam_user" "members" {
  for_each = toset(var.team_members)
  name     = "${var.project_name}-${each.value}"
}

# 그룹 멤버십 (사용자를 그룹에 추가)
resource "aws_iam_group_membership" "cli_users" {
  name  = "${var.project_name}-cli-membership"
  group = aws_iam_group.cli_users.name
  users = [for u in aws_iam_user.members : u.name]
}

# Phase 2: 역할별 세분화 정책 (나중에 활성화)
# resource "aws_iam_policy" "infra_admin" {
#   name        = "petclinic-infra-admin"
#   description = "인프라 관리자 정책"
#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Action = [
#           "ec2:*",
#           "vpc:*",
#           "rds:*",
#           "iam:*"
#         ]
#         Resource = "*"
#       }
#     ]
#   })
# }

# resource "aws_iam_policy" "app_developer" {
#   name        = "petclinic-app-developer"
#   description = "애플리케이션 개발자 정책"
#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Action = [
#           "ecs:*",
#           "ecr:*",
#           "logs:*"
#         ]
#         Resource = "*"
#       }
#     ]
#   })
# }

# =================================================================================
# API Gateway CloudWatch 로깅 역할
# =================================================================================

resource "aws_iam_role" "api_gateway_cloudwatch_logs_role" {
  name = "ApiGatewayCloudWatchLogsRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "ApiGatewayCloudWatchLogsRole"
    ManagedBy = "terraform"
  }
}

resource "aws_iam_role_policy_attachment" "api_gateway_cloudwatch_logs_role_attachment" {
  role       = aws_iam_role.api_gateway_cloudwatch_logs_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

# =================================================================================
# ECS Task Role for Application
# =================================================================================

# ECS Task가 사용할 IAM 역할
resource "aws_iam_role" "ecs_task_role" {
  name = "${var.project_name}-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name      = "${var.project_name}-ecs-task-role"
    ManagedBy = "terraform"
  }
}

# DB 비밀번호 Secret을 읽을 수 있는 IAM 정책
resource "aws_iam_policy" "ecs_db_secret_access_policy" {
  # count를 사용하여 변수가 전달된 경우에만 정책을 생성
  count = var.db_secret_arn != null ? 1 : 0

  name        = "${var.project_name}-ecs-db-secret-access-policy"
  description = "Allows ECS tasks to read the DB secret from Secrets Manager"

  # 이 정책은 특정 Secret에 대한 접근만 허용합니다.
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "secretsmanager:GetSecretValue"
        ],
        Effect   = "Allow",
        Resource = var.db_secret_arn # 변수를 통해 Secret ARN을 전달받음
      }
    ]
  })
}

# 생성한 정책을 ECS Task Role에 연결
resource "aws_iam_role_policy_attachment" "ecs_task_role_db_secret_policy" {
  # count를 사용하여 변수가 전달된 경우에만 연결
  count = var.db_secret_arn != null ? 1 : 0

  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.ecs_db_secret_access_policy[0].arn
}

resource "aws_iam_policy" "ecs_secrets_policy" {
  name        = "petclinic-ecs-secrets-policy-v2"
  description = "Allow ECS tasks to access specific secrets and KMS keys"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "secretsmanager:GetSecretValue",
          "kms:Decrypt",
          "ssm:GetParameters"
        ],
        Resource = "*"
      }
    ]
  })
}

# ECR 접근 및 CloudWatch 로깅을 위한 표준 정책 연결
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Secrets Manager 및 KMS 접근을 위한 커스텀 정책 연결
resource "aws_iam_role_policy_attachment" "ecs_secrets_policy_attachment" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.ecs_secrets_policy.arn
}