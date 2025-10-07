# Parameter Store 레이어 - Spring Cloud Config Server 대체
# 단일 책임: 중앙화된 설정 관리만 담당

# 기존 레이어들의 원격 상태 참조
data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket  = var.tfstate_bucket_name
    key     = "dev/yeonghyeon/network/terraform.tfstate"
    region  = var.aws_region
    profile = var.network_state_profile
  }
}

data "terraform_remote_state" "application" {
  backend = "s3"
  config = {
    bucket  = var.tfstate_bucket_name
    key     = "dev/seokgyeom/application/terraform.tfstate"
    region  = var.aws_region
    profile = var.application_state_profile
  }
}

# Parameter Store 설정 정의
locals {
  # 공통 설정 (모든 서비스가 공유)
  common_parameters = {
    "/petclinic/common/spring.profiles.active"                     = "mysql,aws"
    "/petclinic/common/logging.level.root"                        = "INFO"
    "/petclinic/common/management.endpoints.web.exposure.include" = "*"
    "/petclinic/common/spring.cloud.aws.region.static"            = var.aws_region
    "/petclinic/common/spring.cloud.aws.paramstore.enabled"       = "true"
    "/petclinic/common/spring.cloud.aws.paramstore.prefix"        = "/petclinic"
    "/petclinic/common/spring.cloud.aws.paramstore.profile-separator" = "/"
    "/petclinic/common/spring.cloud.aws.paramstore.fail-fast"     = "true"
  }

  # 환경별 설정
  environment_parameters = {
    "/petclinic/${var.environment}/customers/server.port" = "8080"
    "/petclinic/${var.environment}/vets/server.port"      = "8080"
    "/petclinic/${var.environment}/visits/server.port"    = "8080"
    "/petclinic/${var.environment}/admin/server.port"     = "9090"
    
    # Spring Boot Actuator 설정
    "/petclinic/${var.environment}/customers/management.endpoint.health.show-details" = "always"
    "/petclinic/${var.environment}/vets/management.endpoint.health.show-details"      = "always"
    "/petclinic/${var.environment}/visits/management.endpoint.health.show-details"    = "always"
    "/petclinic/${var.environment}/admin/management.endpoint.health.show-details"     = "always"
  }

  # 보안 파라미터 (데이터베이스 연결 정보)
  secure_parameters = {
    "/petclinic/${var.environment}/customers/database.url"      = "jdbc:mysql://${data.terraform_remote_state.application.outputs.aurora_cluster_endpoint}:3306/petclinic_customers?useSSL=true&requireSSL=true"
    "/petclinic/${var.environment}/customers/database.username" = var.database_username
    "/petclinic/${var.environment}/vets/database.url"          = "jdbc:mysql://${data.terraform_remote_state.application.outputs.aurora_cluster_endpoint}:3306/petclinic_vets?useSSL=true&requireSSL=true"
    "/petclinic/${var.environment}/vets/database.username"     = var.database_username
    "/petclinic/${var.environment}/visits/database.url"        = "jdbc:mysql://${data.terraform_remote_state.application.outputs.aurora_cluster_endpoint}:3306/petclinic_visits?useSSL=true&requireSSL=true"
    "/petclinic/${var.environment}/visits/database.username"   = var.database_username
  }

  # 서비스별 특정 설정
  service_specific_parameters = merge(
    # Customers 서비스 특정 설정
    {
      "/petclinic/${var.environment}/customers/spring.jpa.hibernate.ddl-auto" = "validate"
      "/petclinic/${var.environment}/customers/spring.jpa.show-sql"           = var.enable_sql_logging ? "true" : "false"
    },
    # Vets 서비스 특정 설정
    {
      "/petclinic/${var.environment}/vets/spring.jpa.hibernate.ddl-auto" = "validate"
      "/petclinic/${var.environment}/vets/spring.jpa.show-sql"           = var.enable_sql_logging ? "true" : "false"
    },
    # Visits 서비스 특정 설정
    {
      "/petclinic/${var.environment}/visits/spring.jpa.hibernate.ddl-auto" = "validate"
      "/petclinic/${var.environment}/visits/spring.jpa.show-sql"           = var.enable_sql_logging ? "true" : "false"
    },
    # Admin 서비스 특정 설정
    {
      "/petclinic/${var.environment}/admin/spring.boot.admin.server.enabled" = "true"
      "/petclinic/${var.environment}/admin/logging.level.org.springframework.boot.admin" = "DEBUG"
    }
  )
}

# Parameter Store 모듈
module "parameter_store" {
  source = "../../../modules/parameter-store"

  name_prefix       = var.name_prefix
  environment       = var.environment
  parameter_prefix  = var.parameter_prefix

  # 파라미터 설정
  common_parameters            = local.common_parameters
  environment_parameters       = local.environment_parameters
  secure_parameters           = local.secure_parameters
  service_specific_parameters = local.service_specific_parameters

  # 암호화 설정
  kms_key_id  = var.kms_key_id
  kms_key_arn = var.kms_key_arn

  # IAM 설정
  create_iam_policy = var.create_iam_policy

  # 로깅 설정
  enable_access_logging = true
  log_retention_days    = var.log_retention_days

  # 고급 설정
  parameter_tier    = var.parameter_tier
  allowed_pattern   = var.allowed_pattern
  data_type        = var.data_type

  tags = var.tags
}