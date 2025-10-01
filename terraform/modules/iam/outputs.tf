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