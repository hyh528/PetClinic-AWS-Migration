# PetClinic Staging Environment Variables
# 이 파일은 모든 레이어에서 공통으로 사용하는 변수들을 정의합니다.

# Environment Configuration
environment = "staging"
project_name = "petclinic"
region = "ap-northeast-1"

# Common Tags
common_tags = {
  Project     = "PetClinic"
  Environment = "staging"
  Owner       = "DevOps Team"
  ManagedBy   = "Terraform"
  CostCenter  = "Staging"
}

# VPC Configuration
vpc_cidr = "10.1.0.0/16"
availability_zones = ["ap-northeast-1a", "ap-northeast-1c", "ap-northeast-1d"]

# Database Configuration
db_instance_class = "db.t3.small"
db_allocated_storage = 50

# Application Configuration
ecs_task_cpu = 512
ecs_task_memory = 1024

# Monitoring Configuration
enable_monitoring = true
log_retention_days = 90