
variable "project_name" {
  description = "프로젝트 이름 (예: petclinic)"
  type        = string
}

variable "environment" {
  description = "배포 환경 (예: dev, stg, prd)"
  type        = string
}

variable "aws_region" {
  description = "리소스가 배포될 AWS 리전"
  type        = string
}

variable "services" {
  description = "모니터링할 서비스 목록과 관련 리소스 이름"
  type = map(object({
    ecs_cluster_name           = string
    ecs_service_name           = string
    alb_arn_suffix = string
    alb_target_group_id        = string
  }))
  default = {}
}

variable "tags" {
  description = "리소스에 적용할 공통 태그"
  type        = map(string)
  default     = {}
}

variable "db_cluster_identifier" {
  description = "모니터링할 RDS/Aurora 클러스터의 식별자"
  type        = string
  default     = null
}

variable "cpu_threshold" {
  description = "CPU 사용률 알람 임계값"
  type        = number
  default     = 80
}

variable "memory_threshold" {
  description = "메모리 사용률 알람 임계값"
  type        = number
  default     = 80
}

# variable "lambda_function_arn" {
#   description = "The ARN of the Lambda function to subscribe to the SNS topic."
#   type        = string
#   default     = null
# }
#
# variable "lambda_function_name" {
#   description = "The name of the Lambda function to subscribe to the SNS topic."
#   type        = string
#   default     = null
# }
