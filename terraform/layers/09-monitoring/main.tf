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

data "terraform_remote_state" "aws_native" {
  backend = "s3"
  config = {
    bucket = "petclinic-terraform-state-dev"
    key    = "aws-native/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# CloudWatch 모니터링 모듈 호출
module "cloudwatch" {
  source = "../../../modules/cloudwatch"

  dashboard_name = "PetClinic-Dev-Dashboard"
  aws_region     = "ap-northeast-2"

  # 각 레이어에서 가져온 리소스 정보 (의존성 역전)
  api_gateway_name     = data.terraform_remote_state.aws_native.outputs.api_gateway_name
  ecs_cluster_name     = "petclinic-dev-cluster"
  ecs_service_name     = "petclinic-app-service"
  lambda_function_name = data.terraform_remote_state.aws_native.outputs.lambda_function_name
  aurora_cluster_name  = data.terraform_remote_state.database.outputs.cluster_identifier
  alb_name             = data.terraform_remote_state.application.outputs.alb_name

  log_retention_days = 30
  sns_topic_arn      = aws_sns_topic.alerts.arn

  tags = {
    Project     = "petclinic"
    Environment = "dev"
    Layer       = "monitoring"
    ManagedBy   = "terraform"
    Owner       = "team-petclinic"
    CostCenter  = "training"
  }
}

# ==========================================
# 상세 CloudWatch 알람 설정
# ==========================================

# API Gateway 5XX 에러율 알람
resource "aws_cloudwatch_metric_alarm" "api_gateway_5xx" {
  alarm_name          = "petclinic-dev-api-gateway-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "5XXError"
  namespace           = "AWS/ApiGateway"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "API Gateway 5XX 에러가 5건 이상 발생"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    ApiName = data.terraform_remote_state.aws_native.outputs.api_gateway_name
  }

  tags = {
    Project     = "petclinic"
    Environment = "dev"
    Layer       = "monitoring"
    ManagedBy   = "terraform"
  }
}

# ECS CPU 사용률 알람
resource "aws_cloudwatch_metric_alarm" "ecs_cpu_utilization" {
  alarm_name          = "petclinic-dev-ecs-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "ECS CPU 사용률이 80% 이상"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    ClusterName = "petclinic-dev-cluster"
    ServiceName = "petclinic-app-service"
  }

  tags = {
    Project     = "petclinic"
    Environment = "dev"
    Layer       = "monitoring"
    ManagedBy   = "terraform"
  }
}

# ECS 메모리 사용률 알람
resource "aws_cloudwatch_metric_alarm" "ecs_memory_utilization" {
  alarm_name          = "petclinic-dev-ecs-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "ECS 메모리 사용률이 80% 이상"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    ClusterName = "petclinic-dev-cluster"
    ServiceName = "petclinic-app-service"
  }

  tags = {
    Project     = "petclinic"
    Environment = "dev"
    Layer       = "monitoring"
    ManagedBy   = "terraform"
  }
}

# Aurora CPU 사용률 알람
resource "aws_cloudwatch_metric_alarm" "aurora_cpu_utilization" {
  alarm_name          = "petclinic-dev-aurora-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "Aurora CPU 사용률이 80% 이상"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    DBClusterIdentifier = data.terraform_remote_state.database.outputs.cluster_identifier
  }

  tags = {
    Project     = "petclinic"
    Environment = "dev"
    Layer       = "monitoring"
    ManagedBy   = "terraform"
  }
}

# ALB 5XX 에러율 알람
resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "petclinic-dev-alb-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "ALB 5XX 에러가 5건 이상 발생"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    LoadBalancer = data.terraform_remote_state.application.outputs.alb_arn_suffix
  }

  tags = {
    Project     = "petclinic"
    Environment = "dev"
    Layer       = "monitoring"
    ManagedBy   = "terraform"
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

# S3 버킷 이름 고유성을 위한 랜덤 ID
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# CloudTrail 감사 로그 모듈 호출
module "cloudtrail" {
  source = "../../../modules/cloudtrail"

  cloudtrail_name        = "petclinic-dev-audit-trail"
  cloudtrail_bucket_name = "petclinic-dev-cloudtrail-logs-${random_id.bucket_suffix.hex}"
  aws_region             = "ap-northeast-2"
  log_retention_days     = 90
  sns_topic_arn          = aws_sns_topic.alerts.arn

  tags = {
    Project     = "petclinic"
    Environment = "dev"
    Layer       = "monitoring"
    ManagedBy   = "terraform"
    Owner       = "team-petclinic"
    CostCenter  = "training"
  }
}
