# =============================================================================
# Terraform 레이어 의존성 및 실행 순서 정의
# =============================================================================
# 목적: 
# 1. 레이어별 실행 순서 정의
# 2. 의존성 관계 명시
# 3. 스크립트(Makefile)에서 활용할 메타데이터 제공
# 
# 각 레이어는 terraform_remote_state로 직접 다른 레이어 출력값 참조
# 이 파일은 의존성 순서와 메타데이터만 관리

# =============================================================================
# 레이어 실행 순서 및 의존성 정의 (메타데이터)
# =============================================================================

locals {
  # 레이어별 실행 순서 및 의존성 매핑
  layer_dependencies = {
    "01-network" = {
      order        = 1
      description  = "기본 네트워크 인프라 (VPC, 서브넷, 게이트웨이)"
      dependencies = []
      state_key    = "dev/01-network/terraform.tfstate"
    }

    "02-security" = {
      order        = 2
      description  = "보안 설정 (보안 그룹, IAM, VPC 엔드포인트)"
      dependencies = ["01-network"]
      state_key    = "dev/02-security/terraform.tfstate"
    }

    "03-database" = {
      order        = 3
      description  = "데이터베이스 (Aurora 클러스터)"
      dependencies = ["01-network", "02-security"]
      state_key    = "dev/03-database/terraform.tfstate"
    }

    "04-parameter-store" = {
      order        = 4
      description  = "AWS Parameter Store (Spring Cloud Config 대체)"
      dependencies = ["01-network", "02-security"]
      state_key    = "dev/04-parameter-store/terraform.tfstate"
    }

    "05-cloud-map" = {
      order        = 5
      description  = "AWS Cloud Map (Eureka 서비스 디스커버리 대체)"
      dependencies = ["01-network"]
      state_key    = "dev/05-cloud-map/terraform.tfstate"
    }

    "06-lambda-genai" = {
      order        = 6
      description  = "Lambda + Bedrock (GenAI 서비스)"
      dependencies = ["01-network", "02-security"]
      state_key    = "dev/06-lambda-genai/terraform.tfstate"
    }

    "07-application" = {
      order        = 7
      description  = "애플리케이션 인프라 (ECS, ALB, ECR)"
      dependencies = ["01-network", "02-security", "03-database"]
      state_key    = "dev/07-application/terraform.tfstate"
    }

    "08-api-gateway" = {
      order        = 8
      description  = "AWS API Gateway (Spring Cloud Gateway 대체)"
      dependencies = ["06-lambda-genai", "07-application"]
      state_key    = "dev/08-api-gateway/terraform.tfstate"
    }

    "09-monitoring" = {
      order        = 9
      description  = "모니터링 (CloudWatch, X-Ray)"
      dependencies = ["07-application"]
      state_key    = "dev/09-monitoring/terraform.tfstate"
    }

    "10-aws-native" = {
      order        = 10
      description  = "AWS 네이티브 서비스 통합"
      dependencies = ["04-parameter-store", "05-cloud-map", "06-lambda-genai", "08-api-gateway"]
      state_key    = "dev/10-aws-native/terraform.tfstate"
    }
  }

  # 실행 순서별 정렬된 레이어 목록
  ordered_layers = [
    for layer_name, config in local.layer_dependencies : {
      name         = layer_name
      order        = config.order
      description  = config.description
      dependencies = config.dependencies
      state_key    = config.state_key
    }
  ]
}

# =============================================================================
# 출력값 - 스크립트 및 자동화에서 활용
# =============================================================================

output "layer_execution_order" {
  description = "레이어별 실행 순서 및 의존성 정보 (apply-all.sh, Makefile에서 활용)"
  value = {
    layers = local.ordered_layers

    # 순서별 레이어 이름만 추출 (스크립트에서 사용)
    execution_sequence = [
      for layer in sort([
        for name, config in local.layer_dependencies : "${config.order}-${name}"
      ]) : split("-", layer)[1]
    ]
  }
}

output "state_key_mapping" {
  description = "레이어별 Terraform 상태 키 매핑"
  value = {
    for layer_name, config in local.layer_dependencies : layer_name => config.state_key
  }
}

# 스크립트에서 사용할 간단한 의존성 체크
output "dependency_validation" {
  description = "의존성 검증을 위한 간단한 체크"
  value = {
    total_layers = length(local.layer_dependencies)
    max_order    = max([for config in local.layer_dependencies : config.order]...)

    # 각 레이어가 의존하는 레이어 목록
    dependency_map = {
      for layer_name, config in local.layer_dependencies : layer_name => config.dependencies
    }
  }
}