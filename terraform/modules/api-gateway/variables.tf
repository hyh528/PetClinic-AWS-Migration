# 프로젝트 이름 변수 정의
variable "project_name" {
  description = "The name of the project, used for tagging and resource naming."
  type        = string
}

# 환경 변수 정의
variable "environment" {
  description = "The environment name (e.g., dev, prod), used for tagging and resource naming."
  type        = string
}

# ALB DNS 이름 변수 정의
variable "alb_dns_name" {
  description = "The DNS name of the Application Load Balancer for API Gateway integration."
  type        = string
}

# API Gateway VPC 링크 ID 변수 정의
variable "vpc_link_id" {
  description = "The ID of the VPC Link for API Gateway to integrate with internal ALB."
  type        = string
}

# 대상 네트워크 로드 밸런서 ARN 변수 정의
variable "target_nlb_arn" {
  description = "The ARN of the target Network Load Balancer for the API Gateway VPC Link."
  type        = string
}

# API Gateway 로그 그룹 ARN 변수 정의
variable "api_gateway_log_group_arn" {
  description = "The ARN of the CloudWatch Log Group for API Gateway access logs."
  type        = string
}

# API Gateway 스로틀링 속도 제한 변수 정의
variable "throttling_rate" {
  description = "The API Gateway throttling rate limit (requests per second)."
  type        = number
  default     = 1000
}

# API Gateway 스로틀링 버스트 제한 변수 정의
variable "throttling_burst" {
  description = "The API Gateway throttling burst limit."
  type        = number
  default     = 2000
}
