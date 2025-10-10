# =============================================================================
# 공유 데이터 소스 정의
# =============================================================================
# 목적: 모든 레이어에서 공통으로 사용하는 데이터 소스를 표준화
# 사용법: 각 레이어에서 이 파일을 심볼릭 링크 또는 복사하여 사용

# =============================================================================
# 공통 변수 정의
# =============================================================================

variable "tfstate_bucket_name" {
  description = "Terraform 상태 파일을 저장하는 S3 버킷 이름"
  type        = string
  default     = "petclinic-tfstate-team-jungsu-kopo"
}

variable "aws_region" {
  description = "AWS 리전"
  type        = string
  default     = "ap-northeast-1"
}

variable "aws_profile" {
  description = "AWS CLI 프로파일"
  type        = string
  default     = "petclinic-dev"
}

# =============================================================================
# 레이어별 상태 파일 경로 정의
# =============================================================================

locals {
  # 팀별 상태 파일 경로 매핑
  state_file_paths = {
    # 기본 인프라 레이어
    network     = "dev/yeonghyeon/network/terraform.tfstate"
    security    = "dev/hwigwon/security/terraform.tfstate"
    database    = "dev/junjae/database/terraform.tfstate"
    application = "dev/seokgyeom/application/terraform.tfstate"
    
    # AWS 네이티브 서비스 레이어
    parameter_store = "dev/aws-native/parameter-store/terraform.tfstate"
    cloud_map      = "dev/aws-native/cloud-map/terraform.tfstate"
    lambda_genai   = "dev/aws-native/lambda-genai/terraform.tfstate"
    api_gateway    = "dev/aws-native/api-gateway/terraform.tfstate"
    monitoring     = "dev/aws-native/monitoring/terraform.tfstate"
  }
  
  # 공통 백엔드 설정
  backend_config = {
    bucket  = var.tfstate_bucket_name
    region  = var.aws_region
    profile = var.aws_profile
  }
}

# =============================================================================
# 조건부 데이터 소스 정의 (필요한 경우에만 로드)
# =============================================================================

# Network 레이어 데이터 소스
data "terraform_remote_state" "network" {
  count   = var.enable_network_data_source ? 1 : 0
  backend = "s3"
  config = merge(local.backend_config, {
    key = local.state_file_paths.network
  })
}

# Security 레이어 데이터 소스
data "terraform_remote_state" "security" {
  count   = var.enable_security_data_source ? 1 : 0
  backend = "s3"
  config = merge(local.backend_config, {
    key = local.state_file_paths.security
  })
}

# Database 레이어 데이터 소스
data "terraform_remote_state" "database" {
  count   = var.enable_database_data_source ? 1 : 0
  backend = "s3"
  config = merge(local.backend_config, {
    key = local.state_file_paths.database
  })
}

# Application 레이어 데이터 소스
data "terraform_remote_state" "application" {
  count   = var.enable_application_data_source ? 1 : 0
  backend = "s3"
  config = merge(local.backend_config, {
    key = local.state_file_paths.application
  })
}

# Parameter Store 레이어 데이터 소스
data "terraform_remote_state" "parameter_store" {
  count   = var.enable_parameter_store_data_source ? 1 : 0
  backend = "s3"
  config = merge(local.backend_config, {
    key = local.state_file_paths.parameter_store
  })
}

# Cloud Map 레이어 데이터 소스
data "terraform_remote_state" "cloud_map" {
  count   = var.enable_cloud_map_data_source ? 1 : 0
  backend = "s3"
  config = merge(local.backend_config, {
    key = local.state_file_paths.cloud_map
  })
}

# Lambda GenAI 레이어 데이터 소스
data "terraform_remote_state" "lambda_genai" {
  count   = var.enable_lambda_genai_data_source ? 1 : 0
  backend = "s3"
  config = merge(local.backend_config, {
    key = local.state_file_paths.lambda_genai
  })
}

# API Gateway 레이어 데이터 소스
data "terraform_remote_state" "api_gateway" {
  count   = var.enable_api_gateway_data_source ? 1 : 0
  backend = "s3"
  config = merge(local.backend_config, {
    key = local.state_file_paths.api_gateway
  })
}

# Monitoring 레이어 데이터 소스
data "terraform_remote_state" "monitoring" {
  count   = var.enable_monitoring_data_source ? 1 : 0
  backend = "s3"
  config = merge(local.backend_config, {
    key = local.state_file_paths.monitoring
  })
}

# =============================================================================
# 데이터 소스 활성화 변수 (각 레이어에서 필요한 것만 활성화)
# =============================================================================

variable "enable_network_data_source" {
  description = "Network 레이어 데이터 소스 활성화 여부"
  type        = bool
  default     = false
}

variable "enable_security_data_source" {
  description = "Security 레이어 데이터 소스 활성화 여부"
  type        = bool
  default     = false
}

variable "enable_database_data_source" {
  description = "Database 레이어 데이터 소스 활성화 여부"
  type        = bool
  default     = false
}

variable "enable_application_data_source" {
  description = "Application 레이어 데이터 소스 활성화 여부"
  type        = bool
  default     = false
}

variable "enable_parameter_store_data_source" {
  description = "Parameter Store 레이어 데이터 소스 활성화 여부"
  type        = bool
  default     = false
}

variable "enable_cloud_map_data_source" {
  description = "Cloud Map 레이어 데이터 소스 활성화 여부"
  type        = bool
  default     = false
}

variable "enable_lambda_genai_data_source" {
  description = "Lambda GenAI 레이어 데이터 소스 활성화 여부"
  type        = bool
  default     = false
}

variable "enable_api_gateway_data_source" {
  description = "API Gateway 레이어 데이터 소스 활성화 여부"
  type        = bool
  default     = false
}

variable "enable_monitoring_data_source" {
  description = "Monitoring 레이어 데이터 소스 활성화 여부"
  type        = bool
  default     = false
}

# =============================================================================
# 헬퍼 출력값 (각 레이어에서 사용)
# =============================================================================

output "available_data_sources" {
  description = "사용 가능한 데이터 소스 목록"
  value = {
    network         = var.enable_network_data_source ? try(data.terraform_remote_state.network[0].outputs, {}) : {}
    security        = var.enable_security_data_source ? try(data.terraform_remote_state.security[0].outputs, {}) : {}
    database        = var.enable_database_data_source ? try(data.terraform_remote_state.database[0].outputs, {}) : {}
    application     = var.enable_application_data_source ? try(data.terraform_remote_state.application[0].outputs, {}) : {}
    parameter_store = var.enable_parameter_store_data_source ? try(data.terraform_remote_state.parameter_store[0].outputs, {}) : {}
    cloud_map       = var.enable_cloud_map_data_source ? try(data.terraform_remote_state.cloud_map[0].outputs, {}) : {}
    lambda_genai    = var.enable_lambda_genai_data_source ? try(data.terraform_remote_state.lambda_genai[0].outputs, {}) : {}
    api_gateway     = var.enable_api_gateway_data_source ? try(data.terraform_remote_state.api_gateway[0].outputs, {}) : {}
    monitoring      = var.enable_monitoring_data_source ? try(data.terraform_remote_state.monitoring[0].outputs, {}) : {}
  }
}

# =============================================================================
# 사용 예시 (주석)
# =============================================================================

# 각 레이어에서 이 파일을 사용하는 방법:
#
# 1. 필요한 데이터 소스만 활성화:
#    enable_network_data_source = true
#    enable_database_data_source = true
#
# 2. 데이터 접근:
#    vpc_id = data.terraform_remote_state.network[0].outputs.vpc_id
#    db_endpoint = data.terraform_remote_state.database[0].outputs.cluster_endpoint
#
# 3. 또는 헬퍼 출력값 사용:
#    vpc_id = local.available_data_sources.network.vpc_id