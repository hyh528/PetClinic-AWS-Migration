# ==========================================
# WAF 및 Rate Limiting 설정
# ==========================================

# WAF Web ACL (Rate Limiting 및 보안 규칙)
resource "aws_wafv2_web_acl" "api_gateway_rate_limit" {
  count = var.enable_waf_integration ? 1 : 0

  name  = "${var.name_prefix}-api-rate-limit"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  # Rate Limiting 규칙들 (동적 생성)
  dynamic "rule" {
    for_each = var.waf_rate_limit_rules
    content {
      name     = rule.value.name
      priority = rule.value.priority

      action {
        dynamic "allow" {
          for_each = rule.value.action == "ALLOW" ? [1] : []
          content {}
        }
        dynamic "block" {
          for_each = rule.value.action == "BLOCK" ? [1] : []
          content {}
        }
        dynamic "count" {
          for_each = rule.value.action == "COUNT" ? [1] : []
          content {}
        }
      }

      statement {
        rate_based_statement {
          limit              = rule.value.limit
          aggregate_key_type = "IP"

          # 선택적 스코프 다운 (특정 경로에만 적용 가능)
          scope_down_statement {
            byte_match_statement {
              search_string = "/api/"
              field_to_match {
                uri_path {}
              }
              text_transformation {
                priority = 0
                type     = "LOWERCASE"
              }
              positional_constraint = "CONTAINS"
            }
          }
        }
      }

      visibility_config {
        sampled_requests_enabled   = true
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.name_prefix}-${rule.value.name}"
      }
    }
  }

  # 추가 보안 규칙 - SQL Injection 방지
  rule {
    name     = "SQLInjectionProtection"
    priority = 100

    action {
      block {}
    }

    statement {
      sqli_match_statement {
        field_to_match {
          body {}
        }
        text_transformation {
          priority = 0
          type     = "URL_DECODE"
        }
        text_transformation {
          priority = 1
          type     = "HTML_ENTITY_DECODE"
        }
      }
    }

    visibility_config {
      sampled_requests_enabled   = true
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name_prefix}-SQLInjectionProtection"
    }
  }

  # 추가 보안 규칙 - XSS 방지
  rule {
    name     = "XSSProtection"
    priority = 101

    action {
      block {}
    }

    statement {
      xss_match_statement {
        field_to_match {
          body {}
        }
        text_transformation {
          priority = 0
          type     = "URL_DECODE"
        }
        text_transformation {
          priority = 1
          type     = "HTML_ENTITY_DECODE"
        }
      }
    }

    visibility_config {
      sampled_requests_enabled   = true
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name_prefix}-XSSProtection"
    }
  }

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-api-waf"
    Type = "security"
  })

  visibility_config {
    sampled_requests_enabled   = true
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.name_prefix}-WebACL"
  }
}

# WAF와 API Gateway 연결
resource "aws_wafv2_web_acl_association" "api_gateway" {
  count = var.enable_waf_integration ? 1 : 0

  resource_arn = aws_api_gateway_stage.petclinic.arn
  web_acl_arn  = aws_wafv2_web_acl.api_gateway_rate_limit[0].arn

  depends_on = [
    aws_api_gateway_stage.petclinic,
    aws_wafv2_web_acl.api_gateway_rate_limit
  ]
}

# WAF Rate Limiting 알람 (동적 생성)
resource "aws_cloudwatch_metric_alarm" "waf_rate_limit_alarms" {
  for_each = var.enable_waf_integration && var.enable_rate_limit_monitoring ? {
    for rule in var.waf_rate_limit_rules : rule.name => rule
  } : {}

  alarm_name          = "${var.name_prefix}-waf-${each.key}-blocked"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "BlockedRequests"
  namespace           = "AWS/WAFV2"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.rate_limit_alarm_threshold
  alarm_description   = "WAF ${each.key} 규칙에 의해 차단된 요청이 임계값을 초과했습니다"
  alarm_actions       = var.alarm_actions

  dimensions = {
    WebACL = aws_wafv2_web_acl.api_gateway_rate_limit[0].name
    Rule   = each.key
    Region = data.aws_region.current.name
  }

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-waf-${each.key}-alarm"
    Type = "monitoring"
  })
}

# API Gateway 스로틀링 알람
resource "aws_cloudwatch_metric_alarm" "api_throttling_alarm" {
  count = var.enable_rate_limit_monitoring ? 1 : 0

  alarm_name          = "${var.name_prefix}-api-throttling"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ThrottledRequests"
  namespace           = "AWS/ApiGateway"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.rate_limit_alarm_threshold
  alarm_description   = "API Gateway 스로틀링으로 인한 요청 차단이 임계값을 초과했습니다"
  alarm_actions       = var.alarm_actions

  dimensions = {
    ApiName = aws_api_gateway_rest_api.petclinic.name
    Stage   = aws_api_gateway_stage.petclinic.stage_name
  }

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-api-throttling-alarm"
    Type = "monitoring"
  })
}

# WAF 로그 그룹 (Rate Limiting 이벤트 로깅)
resource "aws_cloudwatch_log_group" "waf_logs" {
  count = var.enable_waf_integration ? 1 : 0

  name              = "/aws/wafv2/${var.name_prefix}-api"
  retention_in_days = var.log_retention_days

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-waf-logs"
    Type = "security-logging"
  })
}

# WAF 로깅 설정 (임시 비활성화 - ARN 형식 문제로 인한 임시 조치)
# resource "aws_wafv2_web_acl_logging_configuration" "api_gateway" {
#   count = var.enable_waf_integration ? 1 : 0
#
#   resource_arn            = aws_wafv2_web_acl.api_gateway_rate_limit[0].arn
#   log_destination_configs = [aws_cloudwatch_log_group.waf_logs[0].arn]
#
#   # 민감한 정보 필터링
#   redacted_fields {
#     single_header {
#       name = "authorization"
#     }
#   }
#
#   redacted_fields {
#     single_header {
#       name = "cookie"
#     }
#   }
#
#   depends_on = [
#     aws_wafv2_web_acl.api_gateway_rate_limit,
#     aws_cloudwatch_log_group.waf_logs
#   ]
# }