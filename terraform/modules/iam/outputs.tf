output "cli_group_name" {
  description = "CLI 사용자 그룹 이름"
  value       = aws_iam_group.cli_users.name
}

output "cli_group_arn" {
  description = "CLI 사용자 그룹 ARN"
  value       = aws_iam_group.cli_users.arn
}

output "user_names" {
  description = "생성된 IAM 사용자 이름 목록"
  value       = [for u in aws_iam_user.members : u.name]
}

output "user_arns" {
  description = "사용자 이름 접미사로 키된 IAM 사용자 ARN 맵"
  value       = { for k, u in aws_iam_user.members : k => u.arn }
}

output "group_membership_name" {
  description = "그룹 멤버십 리소스 이름"
  value       = aws_iam_group_membership.cli_users.name
}

output "api_gateway_cloudwatch_logs_role_arn" {
  description = "API Gateway가 CloudWatch에 로그를 기록하기 위해 사용하는 역할의 ARN입니다."
  value       = aws_iam_role.api_gateway_cloudwatch_logs_role.arn
}

output "ecs_task_role_arn" {
  description = "ARN of the IAM role for ECS tasks"
  value       = aws_iam_role.ecs_task_role.arn
}