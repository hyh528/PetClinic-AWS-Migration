 variable "cluster_name" {
   description = "The name of the ECS cluster."
   type        = string
 }
 
 variable "container_insights_enabled" {
   description = "Whether to enable Container Insights for the ECS cluster."
   type        = bool
   default     = true
 }
 
 variable "task_execution_role_name" {
   description = "The name of the ECS task execution IAM role to look up."
   type        = string
 }

 variable "ecs_secrets_policy_arn" {
   description = "The ARN of the IAM policy for ECS to access Secrets Manager. If null, the policy will not be attached."
   type        = string
   default     = null
 }

 variable "ecs_ssm_policy_arn" {
   description = "The ARN of the IAM policy for ECS to access SSM Parameter Store. If null, the policy will not be attached."
   type        = string
   default     = null
 }