# /terraform/envs/dev/database/parameters.tf

# This file defines all application-level parameters managed by the 'database' module.

locals {
  # Common parameters for Spring Boot applications
  spring_parameters = {
    "spring.datasource.initialization-mode"  = "always",
    "spring.jpa.hibernate.ddl-auto"          = "update",
    "spring.jpa.show-sql"                    = "true",
    "eureka.client.serviceUrl.defaultZone"   = "http://discovery-server:8761/eureka/"
    "logging.level.root"                     = "INFO" 
  }

  # Port configurations for each service
  service_ports = {
    "admin"     = "9090",
    "customers" = "8081",
    "vets"      = "8082",
    "visits"    = "8083",
    "gateway"   = "8080"
  }
}

# == Centralized Parameters for Common Use ==

# Create common Spring Boot parameters under /petclinic/common/
resource "aws_ssm_parameter" "spring_common" {
  for_each = local.spring_parameters
  name     = "/petclinic/common/${each.key}"
  type     = "String"
  value    = each.value
  overwrite = true
  tags = {
    Category = "common-spring"
  }
}

# Create a single, common database URL parameter under /petclinic/common/
resource "aws_ssm_parameter" "common_db_url" {
  name      = "/petclinic/common/database.url"
  type      = "String"
  value     = "jdbc:mysql://${aws_rds_cluster.petclinic_aurora_cluster.endpoint}:3306/${var.db_name}"
  overwrite = true
  tags = {
    Category = "common-database"
  }
}

# Create a single, common database username parameter under /petclinic/common/
resource "aws_ssm_parameter" "common_db_username" {
  name      = "/petclinic/common/database.username"
  type      = "String"
  value     = aws_rds_cluster.petclinic_aurora_cluster.master_username
  overwrite = true
  tags = {
    Category = "common-database"
  }
}

# == Service-Specific Parameters ==

# Create server port parameters for each service under /petclinic/dev/{service-name}/
resource "aws_ssm_parameter" "server_port" {
  for_each  = local.service_ports
  name      = "/petclinic/${var.environment}/${each.key}/server.port"
  type      = "String"
  value     = each.value
  overwrite = true
  tags = {
    Service = each.key
  }
}

# --------------------------------------------------------------------
# [추가할 내용] Aurora가 생성한 DB 비밀번호 Secret의 주소(ARN)를
# Parameter Store에 저장하는 리소스입니다.
# --------------------------------------------------------------------
resource "aws_ssm_parameter" "database_secret_arn_parameter" {
  name  = "/${var.project_name}/${var.environment}/database-secret-arn"
  type  = "String"
  
  # aws_rds_cluster 리소스에서 출력되는 master_user_secret의 ARN 값을 가져옵니다.
  value = aws_rds_cluster.petclinic_aurora_cluster.master_user_secret[0].secret_arn
  
  tags = {
    Name    = "${var.project_name}-db-secret-arn-param"
    Project = var.project_name
  }
}

# --------------------------------------------------------------------
# [추가] Spring Boot Actuator의 Liveness/Readiness 프로브 활성화
# --------------------------------------------------------------------
resource "aws_ssm_parameter" "health_probes_enabled" {
  name      = "/petclinic/common/management/health/probes/enabled"
  type      = "String"
  value     = "true"
  overwrite = true
  tags = {
    Category = "common-actuator"
  }
}




resource "aws_ssm_parameter" "hikari_settings" {
  for_each = {
    "spring.datasource.hikari.max-lifetime"        = "600000", # 10분
    "spring.datasource.hikari.validation-timeout"  = "5000"    # 5초
    }
  name      = "/petclinic/common/${replace(each.key, ".", "/")}"
  type      = "String"
  value     = each.value
  overwrite = true
  tags = {
    Category = "common-hikari"
  }
  
}

# [추가] 각 서비스에 Context Path 설정
resource "aws_ssm_parameter" "service_context_paths" {
  for_each = {
    "admin"     = "/admin-server",
    "customers" = "/customers-service",
    "vets"      = "/vets-service",
    "visits"    = "/visits-service"
  }
  name      = "/petclinic/${var.environment}/${each.key}/server.servlet.context-path"
  type      = "String"
  value     = each.value
  overwrite = true
  tags = {
    Category = "context-path"
    Service  = each.key
  }
}