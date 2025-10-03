# ==========================================
# AWS Native Services 통합 레이어
# ==========================================
# 클린 아키텍처 원칙: 모든 AWS 네이티브 서비스를 조합하는 상위 레이어
# 
# 의존성 계층:
# 1. Network (기반 인프라)
# 2. Security (보안 설정)  
# 3. Database (데이터 레이어)
# 4. AWS Native Services (이 레이어)
# 5. Monitoring (관측성)
#
# 단일 책임: AWS 네이티브 서비스들의 조합 및 통합만 담당
# 개방-폐쇄: 새로운 AWS 서비스 추가 시 기존 코드 수정 없이 확장 가능

# ==========================================
# 원격 상태 데이터 소스 (의존성 역전)
# ==========================================
# 하위 레이어들의 출력값을 참조하여 느슨한 결합 구현

data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = "petclinic-terraform-state-dev"
    key    = "network/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

data "terraform_remote_state" "security" {
  backend = "s3"
  config = {
    bucket = "petclinic-terraform-state-dev"
    key    = "security/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

data "terraform_remote_state" "database" {
  backend = "s3"
  config = {
    bucket = "petclinic-terraform-state-dev"
    key    = "database/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# ==========================================
# 1. API Gateway 모듈 (진입점)
# ==========================================
# 책임: 외부 요청 라우팅 및 AWS 네이티브 서비스 통합
module "api_gateway" {
  source = "../../../modules/api-gateway"

  api_name        = "petclinic-dev-api"
  api_description = "PetClinic Microservices API Gateway"
  stage_name      = "dev"

  # ALB 통합 설정
  alb_listener_arn = data.terraform_remote_state.application.outputs.alb_listener_arn
  vpc_link_id      = aws_api_gateway_vpc_link.main.id

  # 스로틀링 정책
  throttle_rate_limit  = 1000
  throttle_burst_limit = 2000

  tags = local.common_tags
}

# VPC Link 생성 (API Gateway → ALB 연결)
resource "aws_api_gateway_vpc_link" "main" {
  name        = "petclinic-dev-vpc-link"
  description = "VPC Link for PetClinic API Gateway to ALB"
  target_arns = [data.terraform_remote_state.application.outputs.alb_arn]

  tags = local.common_tags
}

# ==========================================
# 2. Parameter Store 모듈 (설정 관리)
# ==========================================
# 책임: 중앙화된 애플리케이션 설정 관리
module "parameter_store" {
  source = "../../../modules/parameter-store"

  environment = "dev"
  
  # 서비스별 파라미터 정의
  parameters = {
    # 공통 설정
    "/petclinic/common/spring.profiles.active" = {
      value = "mysql,aws"
      type  = "String"
    }
    "/petclinic/common/logging.level.root" = {
      value = "INFO"
      type  = "String"
    }
    "/petclinic/common/management.endpoints.web.exposure.include" = {
      value = "*"
      type  = "String"
    }

    # Customers Service 설정
    "/petclinic/dev/customers/server.port" = {
      value = "8080"
      type  = "String"
    }
    "/petclinic/dev/customers/database.url" = {
      value = "jdbc:mysql://${data.terraform_remote_state.database.outputs.cluster_endpoint}:${data.terraform_remote_state.database.outputs.cluster_port}/petclinic_customers"
      type  = "String"
    }
    "/petclinic/dev/customers/database.username" = {
      value = "petclinic"
      type  = "String"
    }

    # Vets Service 설정
    "/petclinic/dev/vets/server.port" = {
      value = "8080"
      type  = "String"
    }
    "/petclinic/dev/vets/database.url" = {
      value = "jdbc:mysql://${data.terraform_remote_state.database.outputs.cluster_endpoint}:${data.terraform_remote_state.database.outputs.cluster_port}/petclinic_vets"
      type  = "String"
    }
    "/petclinic/dev/vets/database.username" = {
      value = "petclinic"
      type  = "String"
    }

    # Visits Service 설정
    "/petclinic/dev/visits/server.port" = {
      value = "8080"
      type  = "String"
    }
    "/petclinic/dev/visits/database.url" = {
      value = "jdbc:mysql://${data.terraform_remote_state.database.outputs.cluster_endpoint}:${data.terraform_remote_state.database.outputs.cluster_port}/petclinic_visits"
      type  = "String"
    }
    "/petclinic/dev/visits/database.username" = {
      value = "petclinic"
      type  = "String"
    }

    # Admin Server 설정
    "/petclinic/dev/admin/server.port" = {
      value = "9090"
      type  = "String"
    }
  }

  tags = local.common_tags
}

# ==========================================
# 3. Cloud Map 모듈 (서비스 디스커버리)
# ==========================================
# 책임: DNS 기반 서비스 디스커버리 제공
module "cloud_map" {
  source = "../../../modules/cloud-map"

  namespace_name = "petclinic.local"
  vpc_id         = data.terraform_remote_state.network.outputs.vpc_id

  # ECS 서비스들을 위한 서비스 등록
  services = {
    customers = {
      description = "Customers Service"
      dns_ttl     = 60
    }
    vets = {
      description = "Vets Service"
      dns_ttl     = 60
    }
    visits = {
      description = "Visits Service"
      dns_ttl     = 60
    }
    admin = {
      description = "Admin Server"
      dns_ttl     = 60
    }
  }

  tags = local.common_tags
}

# ==========================================
# 4. Lambda GenAI 모듈 (AI 서비스)
# ==========================================
# 책임: 서버리스 생성형 AI 서비스 제공
module "lambda_genai" {
  source = "../../../modules/lambda-genai"

  function_name = "petclinic-dev-genai"
  description   = "PetClinic GenAI Service using Amazon Bedrock"

  # Lambda 설정
  runtime       = "python3.11"
  memory_size   = 512
  timeout       = 30
  
  # 환경 변수
  environment_variables = {
    AWS_REGION           = "ap-northeast-2"
    BEDROCK_MODEL_ID     = "anthropic.claude-3-haiku-20240307-v1:0"
    LOG_LEVEL           = "INFO"
  }

  # VPC 설정 (필요시)
  vpc_config = {
    subnet_ids         = values(data.terraform_remote_state.network.outputs.private_app_subnet_ids)
    security_group_ids = [data.terraform_remote_state.security.outputs.lambda_security_group_id]
  }

  tags = local.common_tags
}

# ==========================================
# 공통 태그 정의 (DRY 원칙)
# ==========================================
locals {
  common_tags = {
    Project     = "petclinic"
    Environment = "dev"
    Layer       = "aws-native"
    ManagedBy   = "terraform"
    Owner       = "team-petclinic"
    CostCenter  = "training"
  }
}

# ==========================================
# Application 레이어 원격 상태 (필요시)
# ==========================================
data "terraform_remote_state" "application" {
  backend = "s3"
  config = {
    bucket = "petclinic-terraform-state-dev"
    key    = "application/terraform.tfstate"
    region = "ap-northeast-2"
  }
}