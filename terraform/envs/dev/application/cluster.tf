resource "aws_ecs_cluster" "main" {
  name = "petclinic-cluster"
}

data "aws_iam_role" "ecs_task_execution_role" {
  name = "petclinic-ecs-task-execution-role-v2"
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = data.aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# security 레이어에서 생성한 KMS/Secret 접근 정책을 ECS 작업 실행 역할에 연결
resource "aws_iam_role_policy_attachment" "ecs_secrets_policy_attachment" {
  role       = data.aws_iam_role.ecs_task_execution_role.name
  policy_arn = data.terraform_remote_state.security.outputs.ecs_secrets_policy_arn
}

resource "aws_iam_role_policy_attachment" "ecs_ssm_policy_attachment" {
  role       = data.aws_iam_role.ecs_task_execution_role.name
  policy_arn = data.terraform_remote_state.security.outputs.ecs_ssm_policy_arn
}