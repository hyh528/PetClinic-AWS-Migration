output "cli_group_name" {
  description = "The name of the created IAM group."
  value       = aws_iam_group.cli_users.name
}

output "user_names" {
  description = "The names of the created IAM users."
  value       = [for u in aws_iam_user.members : u.name]
}
/*
output "user_access_keys" {
  description = "The access keys of the created IAM users. This is sensitive."
  value       = { for k, v in aws_iam_access_key.member_keys : k => v.secret }
  sensitive   = true
}
*/
