# 현재 AWS 계정 정보 및 리전 정보 가져오기
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

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

# ECS 태스크 실행 역할 생성
resource "aws_iam_role" "ecs_task_execution" {
  name = "${var.project_name}-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name      = "${var.project_name}-ecs-task-execution-role"
    Component = "iam"
    Purpose   = "ecs-task-execution"
    ManagedBy = "terraform"
  })
}

# ECS 태스크 실행 역할 정책 연결
resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# SSM 읽기 권한 추가 (Parameter Store 접근용)
resource "aws_iam_role_policy_attachment" "ecs_ssm_readonly" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess"
}

# Parameter Store 읽기 권한 정책 연결 (aws_iam_role_policy는 arn 속성이 없으므로 제거)
# resource "aws_iam_role_policy_attachment" "parameter_store_read" {
#   role       = aws_iam_role.ecs_task_execution.name
#   policy_arn = aws_iam_role_policy.parameter_store_read.arn
# }

# Parameter Store 및 Secrets Manager 읽기 권한 추가
resource "aws_iam_role_policy" "parameter_store_read" {
  name = "${var.project_name}-parameter-store-read"
  role = aws_iam_role.ecs_task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/${var.project_name}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = "arn:aws:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:rds!cluster-*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = "arn:aws:kms:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:key/*"
      }
    ]
  })
}

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
