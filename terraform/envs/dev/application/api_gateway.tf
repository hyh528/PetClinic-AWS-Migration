# API Gateway 모듈 호출
module "api_gateway" {
  source = "../../../modules/api-gateway"
  project_name = "petclinic" # 또는 var.project_name
  environment  = "dev"       # 또는 var.environment
  # Network 레이어에서 생성된 ALB의 DNS 이름을 전달합니다.
  alb_dns_name = data.terraform_remote_state.network.outputs.alb_dns_name
  # Security 레이어의 IAM 모듈에서 생성한 로깅 역할 ARN을 전달합니다.
  cloudwatch_role_arn = data.terraform_remote_state.security.outputs.api_gateway_cloudwatch_logs_role_arn
}