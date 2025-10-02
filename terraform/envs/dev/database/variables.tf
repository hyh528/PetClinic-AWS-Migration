variable "aws_region" {
  description = "리소스용 AWS 리전"
  type        = string
}

variable "aws_profile" {
  description = "인증용 AWS 프로필"
  type        = string
}

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "db_name" {
  description = "Name of the main database"
  type        = string
}

variable "db_master_username" {
  description = "Username for the master database user"
  type        = string
  default     = "admin"
}

variable "db_master_password" {
  description = "Password for the master database user"
  type        = string
  sensitive   = true
}