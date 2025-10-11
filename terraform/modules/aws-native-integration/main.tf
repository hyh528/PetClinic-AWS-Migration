# =============================================================================
# AWS Native Services Integration Module
# =============================================================================
# 목적: AWS 네이티브 서비스들 간의 통합과 오케스트레이션
# Well-Architected Framework 준수: 모든 6가지 기둥 적용

# =============================================================================
# 1. API Gateway와 Lambda GenAI 통합
# =============================================================================

# GenAI API 리소스 생성
resource "aws_api_gateway_resource" "genai_resource" {
  count = var.enable_genai_integration ? 1 : 0

  rest_api_id = var.api_gateway_rest_api_id
  parent_id   = var.api_gateway_root_resource_id
  path_part   = "genai"
}

# GenAI API 메서드 생성
resource "aws_api_gateway_method" "genai_method" {
  count = var.enable_genai_integration ? 1 : 0

  rest_api_id   = var.api_gateway_rest_api_id
  resource_id   = aws_api_gateway_resource.genai_resource[0].id
  http_method   = "POST"
  authorization = "NONE"

  # Well-Architected: Security - API 키 요구 (선택사항)
  api_key_required = var.require_api_key
}

# API Gateway와 Lambda 통합
resource "aws_api_gateway_integration" "genai_integration" {
  count = var.enable_genai_integration ? 1 : 0

  rest_api_id = var.api_gateway_rest_api_id
  resource_id = aws_api_gateway_resource.genai_resource[0].id
  http_method = aws_api_gateway_method.genai_method[0].http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_genai_invoke_arn

  # Well-Architected: Performance Efficiency
  timeout_milliseconds = var.genai_integration_timeout_ms

  depends_on = [aws_api_gateway_method.genai_method]
}

# Lambda 권한 부여 (API Gateway에서 Lambda 호출 허용)
resource "aws_lambda_permission" "api_gateway_invoke" {
  count = var.enable_genai_integration ? 1 : 0

  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_genai_function_name
  principal     = "apigateway.amazonaws.com"

  # Well-Architected: Security - 최소 권한 원칙
  source_arn = "${var.api_gateway_execution_arn}/*/*"
}

# =============================================================================
# 2. 서비스 간 연결 검증 (Reliability)
# =============================================================================

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
    ApiName = var.api_gateway_api_name
    Stage   = var.api_gateway_stage_name
  }

  tags = var.common_tags
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
    FunctionName = var.lambda_genai_function_name
  }

  tags = var.common_tags
}

# =============================================================================
# 3. 통합 대시보드 (Operational Excellence)
# =============================================================================

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
            ["AWS/ApiGateway", "Count", "ApiName", var.api_gateway_api_name],
            ["AWS/ApiGateway", "Latency", "ApiName", var.api_gateway_api_name],
            ["AWS/Lambda", "Invocations", "FunctionName", var.lambda_genai_function_name],
            ["AWS/Lambda", "Duration", "FunctionName", var.lambda_genai_function_name]
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

# =============================================================================
# 4. 서비스 상태 체크 (Reliability)
# =============================================================================

# Route 53 Health Check (선택사항)
resource "aws_route53_health_check" "api_gateway_health" {
  count = var.enable_health_checks ? 1 : 0

  fqdn                            = var.api_gateway_domain_name
  port                            = 443
  type                            = "HTTPS"
  resource_path                   = "/health"
  failure_threshold               = "3"
  request_interval                = "30"
  cloudwatch_alarm_region         = var.aws_region
  cloudwatch_alarm_name           = "${var.name_prefix}-api-gateway-health"
  insufficient_data_health_status = "Failure"

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-api-gateway-health-check"
  })
}

# =============================================================================
# 5. 보안 강화 (Security)
# =============================================================================

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

  tags = var.common_tags
}

# WAF와 API Gateway 연결
resource "aws_wafv2_web_acl_association" "api_gateway_waf_association" {
  count = var.enable_waf_protection ? 1 : 0

  resource_arn = var.api_gateway_stage_arn
  web_acl_arn  = aws_wafv2_web_acl.api_gateway_protection[0].arn
}