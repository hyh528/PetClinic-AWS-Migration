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
