# /terraform/modules/config/main.tf

# ===================================================================
# Secrets Manager for Database Credentials
# ===================================================================
resource "aws_secretsmanager_secret" "db_credentials" {
  name = "/${var.project_name}/${var.environment}/database/credentials"
  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_secretsmanager_secret_version" "db_credentials_version" {
  secret_id     = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
  })
}

# ===================================================================
# Vets Service Parameters
# ===================================================================
resource "aws_ssm_parameter" "vets_service_server_port" {
  name  = "/${var.project_name}/${var.environment}/vets-service/server.port"
  type  = "String"
  value = "8080"
  tags = {
    Service     = "vets-service"
    Environment = var.environment
  }
}

resource "aws_ssm_parameter" "vets_service_datasource_url" {
  name  = "/${var.project_name}/${var.environment}/vets-service/spring.datasource.url"
  type  = "String"
  value = "jdbc:mysql://${var.db_endpoint}/${var.db_name}?useUnicode=true"
  tags = {
    Service     = "vets-service"
    Environment = var.environment
  }
}

resource "aws_ssm_parameter" "vets_service_management_endpoints" {
  name  = "/${var.project_name}/${var.environment}/vets-service/management.endpoints.web.exposure.include"
  type  = "String"
  value = "health,info,prometheus"
  tags = {
    Service     = "vets-service"
    Environment = var.environment
  }
}

resource "aws_ssm_parameter" "vets_service_zipkin_endpoint" {
  name  = "/${var.project_name}/${var.environment}/vets-service/management.zipkin.tracing.endpoint"
  type  = "String"
  value = "http://tracing-server:9411/api/v2/spans" # TODO: Update with actual tracing service endpoint
  tags = {
    Service     = "vets-service"
    Environment = var.environment
  }
}

resource "aws_ssm_parameter" "vets_service_eureka_endpoint" {
  name  = "/${var.project_name}/${var.environment}/vets-service/eureka.client.serviceUrl.defaultZone"
  type  = "String"
  value = "http://discovery-server:8761/eureka/" # TODO: Update with actual discovery service endpoint
  tags = {
    Service     = "vets-service"
    Environment = var.environment
  }
}

resource "aws_ssm_parameter" "vets_service_eureka_hostname" {
  name  = "/${var.project_name}/${var.environment}/vets-service/eureka.instance.hostname"
  type  = "String"
  value = "vets-service"
  tags = {
    Service     = "vets-service"
    Environment = var.environment
  }
}

# 참고: DB username/password 파라미터는 Secrets Manager로 이전되어 제거되었습니다.
