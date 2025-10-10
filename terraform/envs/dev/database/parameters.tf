# ===================================================================
# Vets Service General Parameters
# ===================================================================

resource "aws_ssm_parameter" "vets_service_server_port" {
  name  = "/${var.project_name}/vets-service/server.port"
  type  = "String"
  value = "8080"
  tags = {
    Service = "vets-service"
  }
}

resource "aws_ssm_parameter" "vets_service_management_endpoints" {
  name  = "/${var.project_name}/vets-service/management.endpoints.web.exposure.include"
  type  = "String"
  value = "health,info,prometheus"
  tags = {
    Service = "vets-service"
  }
}

resource "aws_ssm_parameter" "vets_service_zipkin_endpoint" {
  name  = "/${var.project_name}/vets-service/management.zipkin.tracing.endpoint"
  type  = "String"
  value = "http://tracing-server:9411/api/v2/spans"
  # TODO: 나중에 생성될 AWS의 Tracing 서비스 주소로 변경해야 합니다.
  tags = {
    Service = "vets-service"
  }
}

resource "aws_ssm_parameter" "vets_service_eureka_endpoint" {
  name  = "/${var.project_name}/vets-service/eureka.client.serviceUrl.defaultZone"
  type  = "String"
  value = "http://discovery-server:8761/eureka/"
  # TODO: 나중에 생성될 AWS의 Discovery 서비스 주소로 변경해야 합니다.
  tags = {
    Service = "vets-service"
  }
}

resource "aws_ssm_parameter" "vets_service_eureka_hostname" {
  name  = "/${var.project_name}/vets-service/eureka.instance.hostname"
  type  = "String"
  value = "vets-service"
  tags = {
    Service = "vets-service"
  }
}

# ===================================================================
# Visits Service General Parameters
# ===================================================================

resource "aws_ssm_parameter" "visits_service_server_port" {
  name  = "/${var.project_name}/visits-service/server.port"
  type  = "String"
  value = "8080"
  tags = {
    Service = "visits-service"
  }
}

resource "aws_ssm_parameter" "visits_service_management_endpoints" {
  name  = "/${var.project_name}/visits-service/management.endpoints.web.exposure.include"
  type  = "String"
  value = "health,info,prometheus"
  tags = {
    Service = "visits-service"
  }
}

resource "aws_ssm_parameter" "visits_service_zipkin_endpoint" {
  name  = "/${var.project_name}/visits-service/management.zipkin.tracing.endpoint"
  type  = "String"
  value = "http://tracing-server:9411/api/v2/spans"
  # TODO: 나중에 생성될 AWS의 Tracing 서비스 주소로 변경해야 합니다.
  tags = {
    Service = "visits-service"
  }
}

resource "aws_ssm_parameter" "visits_service_eureka_endpoint" {
  name  = "/${var.project_name}/visits-service/eureka.client.serviceUrl.defaultZone"
  type  = "String"
  value = "http://discovery-server:8761/eureka/"
  # TODO: 나중에 생성될 AWS의 Discovery 서비스 주소로 변경해야 합니다.
  tags = {
    Service = "visits-service"
  }
}

# ===================================================================
# API Gateway Service General Parameters
# ===================================================================

resource "aws_ssm_parameter" "api_gateway_server_port" {
  name  = "/${var.project_name}/api-gateway/server.port"
  type  = "String"
  value = "8080"
  tags = {
    Service = "api-gateway"
  }
}

resource "aws_ssm_parameter" "api_gateway_management_endpoints" {
  name  = "/${var.project_name}/api-gateway/management.endpoints.web.exposure.include"
  type  = "String"
  value = "health,info,prometheus"
  tags = {
    Service = "api-gateway"
  }
}

resource "aws_ssm_parameter" "api_gateway_zipkin_endpoint" {
  name  = "/${var.project_name}/api-gateway/management.zipkin.tracing.endpoint"
  type  = "String"
  value = "http://tracing-server:9411/api/v2/spans"
  # TODO: 나중에 생성될 AWS의 Tracing 서비스 주소로 변경해야 합니다.
  tags = {
    Service = "api-gateway"
  }
}

resource "aws_ssm_parameter" "api_gateway_eureka_endpoint" {
  name  = "/${var.project_name}/api-gateway/eureka.client.serviceUrl.defaultZone"
  type  = "String"
  value = "http://discovery-server:8761/eureka/"
  # TODO: 나중에 생성될 AWS의 Discovery 서비스 주소로 변경해야 합니다.
  tags = {
    Service = "api-gateway"
  }
}

# ===================================================================
# GenAI Service General Parameters
# ===================================================================

resource "aws_ssm_parameter" "genai_service_server_port" {
  name  = "/${var.project_name}/genai-service/server.port"
  type  = "String"
  value = "8080"
  tags = {
    Service = "genai-service"
  }
}

resource "aws_ssm_parameter" "genai_service_management_endpoints" {
  name  = "/${var.project_name}/genai-service/management.endpoints.web.exposure.include"
  type  = "String"
  value = "health,info,prometheus"
  tags = {
    Service = "genai-service"
  }
}

resource "aws_ssm_parameter" "genai_service_eureka_endpoint" {
  name  = "/${var.project_name}/genai-service/eureka.client.serviceUrl.defaultZone"
  type  = "String"
  value = "http://discovery-server:8761/eureka/"
  # TODO: 나중에 생성될 AWS의 Discovery 서비스 주소로 변경해야 합니다.
  tags = {
    Service = "genai-service"
  }
}

resource "aws_ssm_parameter" "genai_service_openai_api_key" {
  name  = "/${var.project_name}/genai-service/spring.ai.openai.api-key"
  type  = "SecureString" # API 키는 SecureString으로 관리하는 것이 좋습니다.
  value = "YOUR_API_KEY" # TODO: 실제 OpenAI API 키로 변경해야 합니다.
  tags = {
    Service = "genai-service"
  }
}

# ===================================================================
# Admin Server General Parameters
# ===================================================================

resource "aws_ssm_parameter" "admin_server_server_port" {
  name  = "/${var.project_name}/admin-server/server.port"
  type  = "String"
  value = "9090"
  tags = {
    Service = "admin-server"
  }
}

resource "aws_ssm_parameter" "admin_server_management_endpoints" {
  name  = "/${var.project_name}/admin-server/management.endpoints.web.exposure.include"
  type  = "String"
  value = "health,info,prometheus"
  tags = {
    Service = "admin-server"
  }
}

resource "aws_ssm_parameter" "admin_server_eureka_endpoint" {
  name  = "/${var.project_name}/admin-server/eureka.client.serviceUrl.defaultZone"
  type  = "String"
  value = "http://discovery-server:8761/eureka/"
  # TODO: 나중에 생성될 AWS의 Discovery 서비스 주소로 변경해야 합니다.
  tags = {
    Service = "admin-server"
  }
}

# ===================================================================
# Discovery Server General Parameters
# ===================================================================

resource "aws_ssm_parameter" "discovery_server_server_port" {
  name  = "/${var.project_name}/discovery-server/server.port"
  type  = "String"
  value = "8761"
  tags = {
    Service = "discovery-server"
  }
}

resource "aws_ssm_parameter" "discovery_server_eureka_endpoint" {
  name  = "/${var.project_name}/discovery-server/eureka.client.serviceUrl.defaultZone"
  type  = "String"
  value = "http://discovery-server:8761/eureka/"
  # TODO: 나중에 생성될 AWS의 Discovery 서비스 주소로 변경해야 합니다.
  tags = {
    Service = "discovery-server"
  }
}