resource "aws_ecs_cluster" "main" {
  name = var.cluster_name

  setting {
    name  = "containerInsights"
    value = var.container_insights_enabled ? "enabled" : "disabled"
  }
}

data "aws_iam_role" "ecs_task_execution_role" {
  name = var.task_execution_role_name
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = data.aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "ecs_secrets_policy_attachment" {
  count      = var.ecs_secrets_policy_arn != null ? 1 : 0
  role       = data.aws_iam_role.ecs_task_execution_role.name
  policy_arn = var.ecs_secrets_policy_arn
}

resource "aws_iam_role_policy_attachment" "ecs_ssm_policy_attachment" {
  count      = var.ecs_ssm_policy_arn != null ? 1 : 0
  role       = data.aws_iam_role.ecs_task_execution_role.name
  policy_arn = var.ecs_ssm_policy_arn
}