locals {
  # Define parameters that vary per service.
  service_configs = {
    "admin"     = { server_port = "9090" }
    "customers" = { server_port = "8080" }
    "vets"      = { server_port = "8080" }
    "visits"    = { server_port = "8080" }
  }

  # Define common parameters applicable to most services.
  common_parameters = {
    "spring.profiles.active" = "mysql,aws"
    "logging.level.root"     = "INFO"
    "eureka.client.serviceUrl.defaultZone" = "http://discovery-server:8761/eureka/"
  }
}

# Create common parameters for all services using a loop.
resource "aws_ssm_parameter" "common" {
  for_each = local.common_parameters
  name     = "/petclinic/common/${each.key}"
  type     = "String"
  value    = each.value
  tags = {
    Category = "common"
  }
}


# Create server port parameters for each service.
resource "aws_ssm_parameter" "server_port" {
  for_each = local.service_configs
  name     = "/petclinic/${var.environment}/${each.key}/server.port"
  type     = "String"
  value    = each.value.server_port
  tags = {
    Service = each.key
  }
}

# Create database URL and username parameters for each service.
resource "aws_ssm_parameter" "db_url" {
  for_each = { for k, v in local.service_configs : k => v if k != "admin" }

  name  = "/petclinic/${var.environment}/${each.key}/database.url"
  type  = "String"
  value = "jdbc:mysql://aurora-endpoint:3306/petclinic_${each.key}" # Placeholder, will be replaced by actual Aurora endpoint.
  tags = {
    Service = each.key
  }
}

resource "aws_ssm_parameter" "db_user" {
  for_each = { for k, v in local.service_configs : k => v if k != "admin" }

  name  = "/petclinic/${var.environment}/${each.key}/database.username"
  type  = "String"
  value = "petclinic"
  tags = {
    Service = each.key
  }
}