# =============================================================================
# Terraform 모듈 간 의존성 관리
# =============================================================================
# 목적: 모든 레이어 간의 의존성을 중앙에서 관리하고 데이터 소스 연결을 표준화
# 작성자: AWS 네이티브 마이그레이션 팀
# 버전: 1.0.0

# =============================================================================
# 1. 기본 인프라 레이어 (Network, Security, Database)
# =============================================================================

# Network 레이어 원격 상태 (모든 레이어의 기반)
data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket  = var.tfstate_bucket_name
    key     = "dev/yeonghyeon/network/terraform.tfstate"
    region  = var.aws_region
    profile = var.aws_profile
  }
}

# Security 레이어 원격 상태
data "terraform_remote_state" "security" {
  backend = "s3"
  config = {
    bucket  = var.tfstate_bucket_name
    key     = "dev/hwigwon/security/terraform.tfstate"
    region  = var.aws_region
    profile = var.aws_profile
  }
}

# Database 레이어 원격 상태
data "terraform_remote_state" "database" {
  backend = "s3"
  config = {
    bucket  = var.tfstate_bucket_name
    key     = "dev/junjae/database/terraform.tfstate"
    region  = var.aws_region
    profile = var.aws_profile
  }
}

# Application 레이어 원격 상태 (ECS, ALB, ECR)
data "terraform_remote_state" "application" {
  backend = "s3"
  config = {
    bucket  = var.tfstate_bucket_name
    key     = "dev/seokgyeom/application/terraform.tfstate"
    region  = var.aws_region
    profile = var.aws_profile
  }
}

# =============================================================================
# 2. AWS 네이티브 서비스 레이어
# =============================================================================

# Parameter Store 레이어 원격 상태
data "terraform_remote_state" "parameter_store" {
  backend = "s3"
  config = {
    bucket  = var.tfstate_bucket_name
    key     = "dev/aws-native/parameter-store/terraform.tfstate"
    region  = var.aws_region
    profile = var.aws_profile
  }
}

# Cloud Map 레이어 원격 상태
data "terraform_remote_state" "cloud_map" {
  backend = "s3"
  config = {
    bucket  = var.tfstate_bucket_name
    key     = "dev/aws-native/cloud-map/terraform.tfstate"
    region  = var.aws_region
    profile = var.aws_profile
  }
}

# Lambda GenAI 레이어 원격 상태
data "terraform_remote_state" "lambda_genai" {
  backend = "s3"
  config = {
    bucket  = var.tfstate_bucket_name
    key     = "dev/aws-native/lambda-genai/terraform.tfstate"
    region  = var.aws_region
    profile = var.aws_profile
  }
}

# API Gateway 레이어 원격 상태
data "terraform_remote_state" "api_gateway" {
  backend = "s3"
  config = {
    bucket  = var.tfstate_bucket_name
    key     = "dev/aws-native/api-gateway/terraform.tfstate"
    region  = var.aws_region
    profile = var.aws_profile
  }
}

# Monitoring 레이어 원격 상태
data "terraform_remote_state" "monitoring" {
  backend = "s3"
  config = {
    bucket  = var.tfstate_bucket_name
    key     = "dev/aws-native/monitoring/terraform.tfstate"
    region  = var.aws_region
    profile = var.aws_profile
  }
}

# =============================================================================
# 3. 의존성 검증 및 출력값 표준화
# =============================================================================

locals {
  # 의존성 체크: 필수 리소스가 존재하는지 확인
  dependency_checks = {
    vpc_exists              = try(data.terraform_remote_state.network.outputs.vpc_id, null) != null
    security_groups_exist   = try(data.terraform_remote_state.security.outputs.ecs_security_group_id, null) != null
    database_exists         = try(data.terraform_remote_state.database.outputs.cluster_endpoint, null) != null
    application_layer_ready = try(data.terraform_remote_state.application.outputs.ecs_cluster_name, null) != null
  }

  # 네트워크 정보 표준화
  network_info = {
    vpc_id                   = try(data.terraform_remote_state.network.outputs.vpc_id, "")
    vpc_cidr                 = try(data.terraform_remote_state.network.outputs.vpc_cidr, "")
    public_subnet_ids        = try(data.terraform_remote_state.network.outputs.public_subnet_ids, {})
    private_app_subnet_ids   = try(data.terraform_remote_state.network.outputs.private_app_subnet_ids, {})
    private_db_subnet_ids    = try(data.terraform_remote_state.network.outputs.private_db_subnet_ids, {})
    vpc_endpoint_sg_id       = try(data.terraform_remote_state.network.outputs.vpc_endpoint_security_group_id, "")
  }

  # 보안 정보 표준화
  security_info = {
    ecs_security_group_id    = try(data.terraform_remote_state.security.outputs.ecs_security_group_id, "")
    aurora_security_group_id = try(data.terraform_remote_state.security.outputs.aurora_security_group_id, "")
    vpce_security_group_id   = try(data.terraform_remote_state.security.outputs.vpce_security_group_id, "")
  }

  # 데이터베이스 정보 표준화
  database_info = {
    cluster_endpoint = try(data.terraform_remote_state.database.outputs.cluster_endpoint, "")
    reader_endpoint  = try(data.terraform_remote_state.database.outputs.reader_endpoint, "")
    cluster_port     = try(data.terraform_remote_state.database.outputs.cluster_port, 3306)
    database_name    = try(data.terraform_remote_state.database.outputs.database_name, "")
    cluster_arn      = try(data.terraform_remote_state.database.outputs.cluster_arn, "")
  }

  # 애플리케이션 정보 표준화
  application_info = {
    ecs_cluster_name = try(data.terraform_remote_state.application.outputs.ecs_cluster_name, "")
    ecs_cluster_arn  = try(data.terraform_remote_state.application.outputs.ecs_cluster_arn, "")
    alb_arn          = try(data.terraform_remote_state.application.outputs.alb_arn, "")
    alb_dns_name     = try(data.terraform_remote_state.application.outputs.alb_dns_name, "")
    alb_zone_id      = try(data.terraform_remote_state.application.outputs.alb_zone_id, "")
    target_group_arn = try(data.terraform_remote_state.application.outputs.target_group_arn, "")
  }

  # AWS 네이티브 서비스 정보 표준화
  aws_native_info = {
    # Parameter Store
    parameter_store_ready = try(data.terraform_remote_state.parameter_store.outputs.migration_status.parameter_store_ready, false)
    parameter_prefix      = try(data.terraform_remote_state.parameter_store.outputs.spring_cloud_aws_config.parameter_prefix, "/petclinic")
    
    # Cloud Map
    cloud_map_ready    = try(data.terraform_remote_state.cloud_map.outputs.migration_status.cloud_map_ready, false)
    namespace_id       = try(data.terraform_remote_state.cloud_map.outputs.namespace_id, "")
    namespace_name     = try(data.terraform_remote_state.cloud_map.outputs.namespace_name, "")
    service_dns_names  = try(data.terraform_remote_state.cloud_map.outputs.service_dns_names, {})
    
    # Lambda GenAI
    lambda_function_arn        = try(data.terraform_remote_state.lambda_genai.outputs.lambda_function_arn, "")
    lambda_function_invoke_arn = try(data.terraform_remote_state.lambda_genai.outputs.lambda_function_invoke_arn, "")
    lambda_function_name       = try(data.terraform_remote_state.lambda_genai.outputs.lambda_function_name, "")
    
    # API Gateway
    api_gateway_id           = try(data.terraform_remote_state.api_gateway.outputs.api_gateway_id, "")
    api_gateway_execution_arn = try(data.terraform_remote_state.api_gateway.outputs.api_gateway_execution_arn, "")
    api_gateway_invoke_url   = try(data.terraform_remote_state.api_gateway.outputs.api_gateway_invoke_url, "")
  }
}

# =============================================================================
# 4. 의존성 검증 출력
# =============================================================================

output "dependency_status" {
  description = "모든 레이어의 의존성 상태"
  value = {
    checks = local.dependency_checks
    all_dependencies_ready = alltrue([
      local.dependency_checks.vpc_exists,
      local.dependency_checks.security_groups_exist,
      local.dependency_checks.database_exists,
      local.dependency_checks.application_layer_ready
    ])
    timestamp = timestamp()
  }
}

output "integrated_infrastructure_info" {
  description = "통합된 인프라 정보 (모든 레이어)"
  value = {
    network     = local.network_info
    security    = local.security_info
    database    = local.database_info
    application = local.application_info
    aws_native  = local.aws_native_info
  }
}

# =============================================================================
# 5. 레이어별 실행 순서 정의
# =============================================================================

output "execution_order" {
  description = "Terraform 레이어 실행 순서 및 의존성"
  value = {
    phase_1_foundation = {
      order = 1
      layers = ["01-network"]
      description = "기본 네트워크 인프라 (VPC, 서브넷, 게이트웨이)"
      dependencies = []
    }
    
    phase_2_security = {
      order = 2
      layers = ["02-security"]
      description = "보안 설정 (보안 그룹, IAM, VPC 엔드포인트)"
      dependencies = ["01-network"]
    }
    
    phase_3_data = {
      order = 3
      layers = ["03-database"]
      description = "데이터베이스 (Aurora 클러스터)"
      dependencies = ["01-network", "02-security"]
    }
    
    phase_4_application = {
      order = 4
      layers = ["07-application"]
      description = "애플리케이션 인프라 (ECS, ALB, ECR)"
      dependencies = ["01-network", "02-security", "03-database"]
    }
    
    phase_5_aws_native = {
      order = 5
      layers = ["04-parameter-store", "05-cloud-map", "06-lambda-genai"]
      description = "AWS 네이티브 서비스 (Parameter Store, Cloud Map, Lambda)"
      dependencies = ["01-network", "02-security", "03-database", "07-application"]
    }
    
    phase_6_integration = {
      order = 6
      layers = ["08-api-gateway", "09-monitoring"]
      description = "통합 및 모니터링 (API Gateway, CloudWatch)"
      dependencies = ["04-parameter-store", "05-cloud-map", "06-lambda-genai", "07-application"]
    }
  }
}

# =============================================================================
# 6. 마이그레이션 상태 추적
# =============================================================================

output "migration_progress" {
  description = "AWS 네이티브 마이그레이션 진행 상태"
  value = {
    spring_cloud_config_migrated = local.aws_native_info.parameter_store_ready
    eureka_discovery_migrated    = local.aws_native_info.cloud_map_ready
    genai_service_migrated       = local.aws_native_info.lambda_function_arn != ""
    api_gateway_integrated       = local.aws_native_info.api_gateway_id != ""
    
    migration_percentage = length([
      for k, v in {
        parameter_store = local.aws_native_info.parameter_store_ready
        cloud_map      = local.aws_native_info.cloud_map_ready
        lambda_genai   = local.aws_native_info.lambda_function_arn != ""
        api_gateway    = local.aws_native_info.api_gateway_id != ""
      } : k if v
    ]) / 4 * 100
    
    last_updated = timestamp()
  }
}