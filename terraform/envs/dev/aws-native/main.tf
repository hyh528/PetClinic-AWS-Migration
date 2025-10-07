# ==========================================
# AWS Native Services 통합 레이어 (Orchestration Layer)
# ==========================================
# 
# 🏗️ 클린 아키텍처 원칙 적용:
# - Single Responsibility: 오직 서비스 간 통합과 오케스트레이션만 담당
# - Open/Closed: 새로운 서비스 추가 시 기존 코드 수정 없이 확장 가능
# - Dependency Inversion: 추상화된 인터페이스에 의존
#
# 🏛️ AWS Well-Architected Framework 6가지 기둥:
# 1. Operational Excellence: 자동화된 배포 및 모니터링
# 2. Security: 최소 권한 원칙 및 암호화
# 3. Reliability: 다중 AZ 및 장애 복구
# 4. Performance Efficiency: 적절한 리소스 크기 및 최적화
# 5. Cost Optimization: 사용량 기반 과금 및 리소스 최적화
# 6. Sustainability: 서버리스 및 관리형 서비스 활용

# ==========================================
# 의존성 역전 원칙 (Dependency Inversion)
# ==========================================
# 구체적인 구현이 아닌 추상화된 인터페이스에 의존

# 기반 인프라 레이어들의 출력값 참조
data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = "petclinic-tfstate-team-jungsu-kopo"
    key    = "dev/yeonghyeon/network/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

data "terraform_remote_state" "security" {
  backend = "s3"
  config = {
    bucket = "petclinic-tfstate-team-jungsu-kopo"
    key    = "dev/hwigwon/security/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

data "terraform_remote_state" "database" {
  backend = "s3"
  config = {
    bucket = "petclinic-tfstate-team-jungsu-kopo"
    key    = "dev/junje/database/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# AWS 네이티브 서비스 레이어들의 출력값 참조
data "terraform_remote_state" "api_gateway" {
  backend = "s3"
  config = {
    bucket = "petclinic-tfstate-team-jungsu-kopo"
    key    = "dev/api-gateway/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

data "terraform_remote_state" "parameter_store" {
  backend = "s3"
  config = {
    bucket = "petclinic-tfstate-team-jungsu-kopo"
    key    = "dev/parameter-store/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

data "terraform_remote_state" "cloud_map" {
  backend = "s3"
  config = {
    bucket = "petclinic-tfstate-team-jungsu-kopo"
    key    = "dev/cloud-map/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

data "terraform_remote_state" "lambda_genai" {
  backend = "s3"
  config = {
    bucket = "petclinic-tfstate-team-jungsu-kopo"
    key    = "dev/lambda-genai/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

data "terraform_remote_state" "application" {
  backend = "s3"
  config = {
    bucket = "petclinic-tfstate-team-jungsu-kopo"
    key    = "dev/seokgyeom/application/terraform.tfstate"
    region = "ap-northeast-2"
  }
}

# ==========================================
# 서비스 통합 및 오케스트레이션 (Single Responsibility)
# ==========================================
# 책임: AWS 네이티브 서비스들 간의 통합과 연결만 담당

# 1. API Gateway와 Lambda GenAI 통합
resource "aws_api_gateway_integration" "genai_integration" {
  count = var.enable_genai_integration ? 1 : 0

  rest_api_id = data.terraform_remote_state.api_gateway.outputs.rest_api_id
  resource_id = aws_api_gateway_resource.genai_resource[0].id
  http_method = aws_api_gateway_method.genai_method[0].http_method

  integration_http_method = "POST"
  type                   = "AWS_PROXY"
  uri                    = data.terraform_remote_state.lambda_genai.outputs.invoke_arn

  # Well-Architected: Performance Efficiency
  timeout_milliseconds = var.genai_integration_timeout_ms

  depends_on = [aws_api_gateway_method.genai_method]
}

# GenAI API 리소스 생성
resource "aws_api_gateway_resource" "genai_resource" {
  count = var.enable_genai_integration ? 1 : 0

  rest_api_id = data.terraform_remote_state.api_gateway.outputs.rest_api_id
  parent_id   = data.terraform_remote_state.api_gateway.outputs.root_resource_id
  path_part   = "genai"
}

# GenAI API 메서드 생성
resource "aws_api_gateway_method" "genai_method" {
  count = var.enable_genai_integration ? 1 : 0

  rest_api_id   = data.terraform_remote_state.api_gateway.outputs.rest_api_id
  resource_id   = aws_api_gateway_resource.genai_resource[0].id
  http_method   = "POST"
  authorization = "NONE"

  # Well-Architected: Security - API 키 요구 (선택사항)
  api_key_required = var.require_api_key
}

# Lambda 권한 부여 (API Gateway에서 Lambda 호출 허용)
resource "aws_lambda_permission" "api_gateway_invoke" {
  count = var.enable_genai_integration ? 1 : 0

  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = data.terraform_remote_state.lambda_genai.outputs.function_name
  principal     = "apigateway.amazonaws.com"

  # Well-Architected: Security - 최소 권한 원칙
  source_arn = "${data.terraform_remote_state.api_gateway.outputs.execution_arn}/*/*"
}

# ==========================================
# 2. 서비스 간 연결 검증 (Reliability)
# ==========================================
# 책임: 서비스 간 연결 상태 모니터링 및 헬스체크

# CloudWatch 알람 - API Gateway 4xx 에러
resource "aws_cloudwatch_metric_alarm" "api_gateway_4xx_errors" {
  count = var.enable_monitoring ? 1 : 0

  alarm_name          = "${var.name_prefix}-api-gateway-4xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "4XXError"
  namespace           = "AWS/ApiGateway"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.api_gateway_4xx_threshold
  alarm_description   = "This metric monitors API Gateway 4xx errors"
  alarm_actions       = var.alarm_actions

  dimensions = {
    ApiName = data.terraform_remote_state.api_gateway.outputs.api_name
    Stage   = data.terraform_remote_state.api_gateway.outputs.stage_name
  }

  tags = local.common_tags
}

# CloudWatch 알람 - Lambda GenAI 에러
resource "aws_cloudwatch_metric_alarm" "lambda_genai_errors" {
  count = var.enable_monitoring && var.enable_genai_integration ? 1 : 0

  alarm_name          = "${var.name_prefix}-lambda-genai-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.lambda_error_threshold
  alarm_description   = "This metric monitors Lambda GenAI function errors"
  alarm_actions       = var.alarm_actions

  dimensions = {
    FunctionName = data.terraform_remote_state.lambda_genai.outputs.function_name
  }

  tags = local.common_tags
}

# ==========================================
# 3. 통합 대시보드 (Operational Excellence)
# ==========================================
# 책임: 모든 AWS 네이티브 서비스의 통합 모니터링

resource "aws_cloudwatch_dashboard" "aws_native_integration" {
  count = var.create_integration_dashboard ? 1 : 0

  dashboard_name = "${var.name_prefix}-aws-native-integration"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/ApiGateway", "Count", "ApiName", data.terraform_remote_state.api_gateway.outputs.api_name],
            ["AWS/ApiGateway", "Latency", "ApiName", data.terraform_remote_state.api_gateway.outputs.api_name],
            ["AWS/Lambda", "Invocations", "FunctionName", data.terraform_remote_state.lambda_genai.outputs.function_name],
            ["AWS/Lambda", "Duration", "FunctionName", data.terraform_remote_state.lambda_genai.outputs.function_name]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "AWS Native Services Integration Metrics"
          period  = 300
        }
      }
    ]
  })
}

# ==========================================
# 4. 비용 최적화 태그 (Cost Optimization)
# ==========================================
# 책임: 통합된 비용 추적 및 최적화

locals {
  # Well-Architected: Cost Optimization
  common_tags = {
    Project         = var.project_name
    Environment     = var.environment
    Layer          = "aws-native-integration"
    ManagedBy      = "terraform"
    Owner          = var.owner
    CostCenter     = var.cost_center
    
    # 비용 추적을 위한 태그
    Service        = "integration"
    Component      = "orchestration"
    
    # 자동화를 위한 태그
    AutoShutdown   = var.auto_shutdown_enabled ? "true" : "false"
    BackupRequired = var.backup_required ? "true" : "false"
    
    # 보안을 위한 태그
    DataClass      = var.data_classification
    Compliance     = var.compliance_requirements
  }
}

# ==========================================
# 5. 서비스 상태 체크 (Reliability)
# ==========================================
# 책임: 통합된 서비스들의 상태 모니터링

# Route 53 Health Check (선택사항)
resource "aws_route53_health_check" "api_gateway_health" {
  count = var.enable_health_checks ? 1 : 0

  fqdn                            = data.terraform_remote_state.api_gateway.outputs.api_domain_name
  port                            = 443
  type                            = "HTTPS"
  resource_path                   = "/health"
  failure_threshold               = "3"
  request_interval                = "30"
  cloudwatch_alarm_region         = var.aws_region
  cloudwatch_alarm_name           = "${var.name_prefix}-api-gateway-health"
  insufficient_data_health_status = "Failure"

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-api-gateway-health-check"
  })
}

# ==========================================
# 6. 보안 강화 (Security)
# ==========================================
# 책임: 서비스 간 통신 보안 강화

# WAF Web ACL (API Gateway 보호)
resource "aws_wafv2_web_acl" "api_gateway_protection" {
  count = var.enable_waf_protection ? 1 : 0

  name  = "${var.name_prefix}-api-gateway-waf"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  # Rate limiting rule
  rule {
    name     = "RateLimitRule"
    priority = 1

    override_action {
      none {}
    }

    statement {
      rate_based_statement {
        limit              = var.waf_rate_limit
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name_prefix}-RateLimitRule"
      sampled_requests_enabled   = true
    }

    action {
      block {}
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.name_prefix}-WAF"
    sampled_requests_enabled   = true
  }

  tags = local.common_tags
}

# WAF와 API Gateway 연결
resource "aws_wafv2_web_acl_association" "api_gateway_waf_association" {
  count = var.enable_waf_protection ? 1 : 0

  resource_arn = data.terraform_remote_state.api_gateway.outputs.stage_arn
  web_acl_arn  = aws_wafv2_web_acl.api_gateway_protection[0].arn
}
