# ==========================================
# Monitoring 레이어: CloudWatch 통합 모니터링
# ==========================================
# AWS 네이티브 서비스들의 통합 모니터링 시스템

# 원격 상태 데이터 소스들
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

data "terraform_remote_state" "application" {
  backend = "s3"
  config = {
    bucket = "petclinic-terraform-state-dev"
    key    = "application/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

data "terraform_remote_state" "api_gateway" {
  backend = "s3"
  config = {
    bucket = "petclinic-terraform-state-dev"
    key    = "api-gateway/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

data "terraform_remote_state" "lambda_genai" {
  backend = "s3"
  config = {
    bucket = "petclinic-terraform-state-dev"
    key    = "lambda-genai/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# CloudWatch 모니터링 모듈 호출
module "cloudwatch" {
  source = "../../../modules/cloudwatch"

  dashboard_name        = "PetClinic-Dev-Dashboard"
  aws_region           = "ap-northeast-2"
  
  # 각 레이어에서 가져온 리소스 정보
  api_gateway_name     = data.terraform_remote_state.api_gateway.outputs.api_gateway_name
  ecs_cluster_name     = "petclinic-dev-cluster"
  ecs_service_name     = "petclinic-app-service"
  lambda_function_name = data.terraform_remote_state.lambda_genai.outputs.function_name
  aurora_cluster_name  = data.terraform_remote_state.database.outputs.cluster_identifier
  alb_name            = data.terraform_remote_state.application.outputs.alb_name
  
  log_retention_days   = 30
  sns_topic_arn       = aws_sns_topic.alerts.arn

  tags = {
    Project     = "petclinic"
    Environment = "dev"
    Layer       = "monitoring"
    ManagedBy   = "terraform"
    Owner       = "team-petclinic"
    CostCenter  = "training"
  }
}

# SNS 토픽 생성 (알람 알림용)
resource "aws_sns_topic" "alerts" {
  name = "petclinic-dev-alerts"

  tags = {
    Project     = "petclinic"
    Environment = "dev"
    Layer       = "monitoring"
    ManagedBy   = "terraform"
    Owner       = "team-petclinic"
    CostCenter  = "training"
  }
}

# SNS 토픽 구독 (이메일 알림)
resource "aws_sns_topic_subscription" "email_alerts" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# X-Ray 추적 설정
resource "aws_xray_sampling_rule" "petclinic" {
  rule_name      = "PetClinicSampling"
  priority       = 9000
  version        = 1
  reservoir_size = 1
  fixed_rate     = 0.1
  url_path       = "*"
  host           = "*"
  http_method    = "*"
  service_type   = "*"
  service_name   = "*"
  resource_arn   = "*"

  tags = {
    Project     = "petclinic"
    Environment = "dev"
    Layer       = "monitoring"
    ManagedBy   = "terraform"
  }
}