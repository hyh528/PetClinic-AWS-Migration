output "cluster_id" {
  description = "The ID of the ECS cluster."
  value       = aws_ecs_cluster.main.id
}

output "cluster_arn" {
  description = "The ARN of the ECS cluster."
  value       = aws_ecs_cluster.main.arn
}

output "cluster_name" {
  description = "The name of the ECS cluster."
  value       = aws_ecs_cluster.main.name
}

output "task_execution_role_arn" {
  description = "The ARN of the ECS task execution role."
  value       = data.aws_iam_role.ecs_task_execution_role.arn
}

output "task_execution_role_name" {
  description = "The name of the ECS task execution role."
  value       = data.aws_iam_role.ecs_task_execution_role.name
}