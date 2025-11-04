# API Gateway 모듈 호출
module "api_gateway" {
  source = "../../../modules/api-gateway"

  project_name = "petclinic" # 또는 var.project_name
  environment  = "dev"       # 또는 var.environment
  alb_dns_name = module.alb.dns_name

  # Security 레이어의 IAM 모듈에서 생성한 로깅 역할 ARN을 전달합니다.
  #cloudwatch_role_arn = data.terraform_remote_state.security.outputs.api_gateway_cloudwatch_logs_role_arn

  # API Gateway 라우팅 규칙 정의
  direct_top_level_services = {
    "admin" = "admin-server"
  }
  api_sub_services = {
    "customers" = "customers-service"
    "vets"      = "vets-service"
    "visits"    = "visits-service"
  }
}