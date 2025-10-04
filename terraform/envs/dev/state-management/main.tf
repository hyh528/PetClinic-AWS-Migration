# ==========================================
# 개발 환경 Terraform 상태 관리 설정
# ==========================================

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ==========================================
# Provider 설정
# ==========================================

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      Project     = "petclinic"
      ManagedBy   = "terraform"
      Layer       = "state-management"
    }
  }
}

# 복제용 Provider (교차 리전 복제 시 사용)
provider "aws" {
  alias  = "replica"
  region = var.replica_region

  default_tags {
    tags = {
      Environment = var.environment
      Project     = "petclinic"
      ManagedBy   = "terraform"
      Layer       = "state-management-replica"
    }
  }
}

# ==========================================
# 상태 관리 모듈 호출
# ==========================================

module "state_management" {
  source = "../../../modules/state-management"

  # 기본 설정
  environment     = var.environment
  bucket_name     = var.bucket_name
  lock_table_name = var.lock_table_name

  # 보안 설정
  force_destroy                   = var.force_destroy
  enable_cross_region_replication = var.enable_cross_region_replication
  replica_region                  = var.replica_region
  kms_key_deletion_window        = var.kms_key_deletion_window
  versioning_status              = var.versioning_status

  # 비용 최적화 설정
  lifecycle_rules         = var.lifecycle_rules
  point_in_time_recovery = var.point_in_time_recovery

  # 모니터링 설정
  enable_cloudtrail_logging = var.enable_cloudtrail_logging
  notification_email       = var.notification_email

  # 태그
  tags = merge(var.tags, {
    Environment = var.environment
    Layer       = "state-management"
  })
}

# ==========================================
# 로컬 값 정의
# ==========================================

locals {
  # 백엔드 설정 템플릿
  backend_config_template = templatefile("${path.module}/templates/backend.tf.tpl", {
    bucket         = module.state_management.s3_bucket_id
    region         = var.aws_region
    dynamodb_table = module.state_management.dynamodb_table_name
    kms_key_id     = module.state_management.kms_key_arn
  })

  # 환경별 백엔드 키 매핑
  backend_keys = {
    network        = "envs/${var.environment}/network/terraform.tfstate"
    security       = "envs/${var.environment}/security/terraform.tfstate"
    database       = "envs/${var.environment}/database/terraform.tfstate"
    application    = "envs/${var.environment}/application/terraform.tfstate"
    monitoring     = "envs/${var.environment}/monitoring/terraform.tfstate"
    aws-native     = "envs/${var.environment}/aws-native/terraform.tfstate"
    api-gateway    = "envs/${var.environment}/api-gateway/terraform.tfstate"
    parameter-store = "envs/${var.environment}/parameter-store/terraform.tfstate"
    cloud-map      = "envs/${var.environment}/cloud-map/terraform.tfstate"
    lambda-genai   = "envs/${var.environment}/lambda-genai/terraform.tfstate"
  }
}

# ==========================================
# 백엔드 설정 파일 생성
# ==========================================

# 각 레이어별 백엔드 설정 파일 생성
resource "local_file" "backend_configs" {
  for_each = local.backend_keys

  filename = "${path.module}/../${each.key}/backend.tf"
  content = templatefile("${path.module}/templates/backend.tf.tpl", {
    bucket         = module.state_management.s3_bucket_id
    key            = each.value
    region         = var.aws_region
    dynamodb_table = module.state_management.dynamodb_table_name
    kms_key_id     = module.state_management.kms_key_arn
  })

  file_permission = "0644"
}

# 마이그레이션 스크립트 생성
resource "local_file" "migration_script" {
  filename = "${path.module}/scripts/migrate-to-remote-state.sh"
  content = templatefile("${path.module}/templates/migrate-script.sh.tpl", {
    bucket         = module.state_management.s3_bucket_id
    region         = var.aws_region
    dynamodb_table = module.state_management.dynamodb_table_name
    kms_key_id     = module.state_management.kms_key_arn
    environment    = var.environment
  })

  file_permission = "0755"
}

# README 파일 생성
resource "local_file" "readme" {
  filename = "${path.module}/README.md"
  content = templatefile("${path.module}/templates/README.md.tpl", {
    bucket_name    = module.state_management.s3_bucket_id
    table_name     = module.state_management.dynamodb_table_name
    kms_key_arn    = module.state_management.kms_key_arn
    environment    = var.environment
    backend_keys   = local.backend_keys
  })

  file_permission = "0644"
}