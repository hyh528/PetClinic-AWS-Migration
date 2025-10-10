# PetClinic Production Environment Variables
# 이 파일은 모든 레이어에서 공통으로 사용하는 변수들을 정의합니다.

# Environment Configuration
environment = "prod"
project_name = "petclinic"
region = "ap-northeast-1"

# Common Tags
common_tags = {
  Project     = "PetClinic"
  Environment = "prod"
  Owner       = "DevOps Team"
  ManagedBy   = "Terraform"
  CostCenter  = "Production"
}

# VPC Configuration
vpc_cidr = "10.2.0.0/16"
availability_zones = ["ap-northeast-1a", "ap-northeast-1c", "ap-northeast-1d"]

# Database Configuration
db_instance_class = "db.t3.medium"
db_allocated_storage = 100

# Application Configuration
ecs_task_cpu = 1024
ecs_task_memory = 2048

# Monitoring Configuration
enable_monitoring = true
log_retention_days = 365