data "aws_region" "current" {}

# ALB 보안 그룹
resource "aws_security_group" "alb" {
  name        = "${var.name_prefix}-alb-sg"
  description = "Security group for ALB"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-alb-sg"
    Environment = var.environment
    Tier        = "edge-lb"
  })
}

# IPv4 인그레스 80/443 (allow_ingress_cidrs_ipv4로 매개변수화)
resource "aws_vpc_security_group_ingress_rule" "alb_http_ipv4" {
  for_each = toset(var.allow_ingress_cidrs_ipv4)

  security_group_id = aws_security_group.alb.id

  description = "Allow HTTP (80) from configured IPv4 CIDR"
  cidr_ipv4   = each.value
  from_port   = 80
  to_port     = 80
  ip_protocol = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "alb_https_ipv4" {
  for_each = toset(var.allow_ingress_cidrs_ipv4)

  security_group_id = aws_security_group.alb.id

  description = "Allow HTTPS (443) from configured IPv4 CIDR"
  cidr_ipv4   = each.value
  from_port   = 443
  to_port     = 443
  ip_protocol = "tcp"
}

# IPv6 인그레스 80/443 (선택 사항)
resource "aws_vpc_security_group_ingress_rule" "alb_http_ipv6" {
  count = var.allow_ingress_ipv6_any ? 1 : 0

  security_group_id = aws_security_group.alb.id

  description = "Allow HTTP (80) from IPv6 any"
  cidr_ipv6   = "::/0"
  from_port   = 80
  to_port     = 80
  ip_protocol = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "alb_https_ipv6" {
  count = var.allow_ingress_ipv6_any ? 1 : 0

  security_group_id = aws_security_group.alb.id

  description = "Allow HTTPS (443) from IPv6 any"
  cidr_ipv6   = "::/0"
  from_port   = 443
  to_port     = 443
  ip_protocol = "tcp"
}

# 송신: 모두 허용 (나중에 ECS SG로 강화 가능)
resource "aws_vpc_security_group_egress_rule" "alb_all_out" {
  security_group_id = aws_security_group.alb.id

  description = "Allow all outbound traffic"
  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"
}

# 애플리케이션 로드 밸런서 (듀얼스택)
resource "aws_lb" "this" {
  name               = "${var.name_prefix}-alb"
  load_balancer_type = "application"
  internal           = false
  ip_address_type    = "ipv4"
  subnets            = var.public_subnet_ids
  security_groups    = [aws_security_group.alb.id]

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-alb"
    Environment = var.environment
    Tier        = "edge-lb"
  })
}

# ECS 태스크용 기본 대상 그룹 (awsvpc -> target_type ip)
resource "aws_lb_target_group" "default" {
  name        = "${var.name_prefix}-tg"
  port        = var.target_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    path                = var.health_check_path
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 30
    timeout             = 5
    matcher             = "200-399"
  }

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-tg"
    Environment = var.environment
  })
}

# 인증서가 있을 때 HTTP (80) 리스너를 HTTPS (443)로 리디렉션
resource "aws_lb_listener" "http_redirect" {
  count = var.create_http_redirect && var.certificate_arn != "" ? 1 : 0

  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# HTTPS가 아직 구성되지 않은 경우 HTTP (80) 리스너 포워딩 (폴백)
resource "aws_lb_listener" "http_forward" {
  count = var.create_http_redirect && var.certificate_arn != "" ? 0 : 1

  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.default.arn
  }
}

# ACM을 사용한 HTTPS (443) 리스너
resource "aws_lb_listener" "https" {
  count = var.certificate_arn != "" ? 1 : 0

  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"

  certificate_arn = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.default.arn
  }
}

# ==========================================
# WAF Rate Limiting 및 보안 설정
# ==========================================

# WAF Web ACL for ALB
resource "aws_wafv2_web_acl" "alb_rate_limit" {
  count = var.enable_waf_rate_limiting ? 1 : 0

  name  = "${var.name_prefix}-alb-waf"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  # Rate Limiting 규칙 - 일반적인 제한 (5분간)
  rule {
    name     = "GeneralRateLimit"
    priority = 1

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.rate_limit_per_ip
        aggregate_key_type = "IP"
        
        # actuator 경로 제외 (헬스 체크는 Rate Limit 적용 안 함)
        scope_down_statement {
          not_statement {
            statement {
              byte_match_statement {
                search_string = "/actuator/"
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
      }
    }

    visibility_config {
      sampled_requests_enabled   = true
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name_prefix}-GeneralRateLimit"
    }
  }

  # Rate Limiting 규칙 - 버스트 제한 (1분간)
  rule {
    name     = "BurstRateLimit"
    priority = 2

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = var.rate_limit_burst_per_ip
        aggregate_key_type = "IP"

        # 특정 경로에 대한 더 엄격한 제한 (actuator 헬스 체크 제외)
        scope_down_statement {
          and_statement {
            statement {
              or_statement {
                statement {
                  byte_match_statement {
                    search_string = "/api/"
                    field_to_match {
                      uri_path {}
                    }
                    text_transformation {
                      priority = 0
                      type     = "LOWERCASE"
                    }
                    positional_constraint = "STARTS_WITH"
                  }
                }
                statement {
                  byte_match_statement {
                    search_string = "/admin/"
                    field_to_match {
                      uri_path {}
                    }
                    text_transformation {
                      priority = 0
                      type     = "LOWERCASE"
                    }
                    positional_constraint = "STARTS_WITH"
                  }
                }
              }
            }
            # actuator 경로 제외 (헬스 체크는 Rate Limit 적용 안 함)
            statement {
              not_statement {
                statement {
                  byte_match_statement {
                    search_string = "/actuator/"
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
          }
        }
      }
    }

    visibility_config {
      sampled_requests_enabled   = true
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name_prefix}-BurstRateLimit"
    }
  }

  # 지역 차단 규칙 (선택사항)
  dynamic "rule" {
    for_each = var.enable_geo_blocking && length(var.blocked_countries) > 0 ? [1] : []
    content {
      name     = "GeoBlocking"
      priority = 10

      action {
        block {}
      }

      statement {
        geo_match_statement {
          country_codes = var.blocked_countries
        }
      }

      visibility_config {
        sampled_requests_enabled   = true
        cloudwatch_metrics_enabled = true
        metric_name                = "${var.name_prefix}-GeoBlocking"
      }
    }
  }

  # SQL Injection 방지 규칙
  dynamic "rule" {
    for_each = var.enable_security_rules ? [1] : []
    content {
      name     = "SQLInjectionProtection"
      priority = 20

      action {
        block {}
      }

      statement {
        sqli_match_statement {
          field_to_match {
            all_query_arguments {}
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
  }

  # XSS 방지 규칙
  dynamic "rule" {
    for_each = var.enable_security_rules ? [1] : []
    content {
      name     = "XSSProtection"
      priority = 21

      action {
        block {}
      }

      statement {
        xss_match_statement {
          field_to_match {
            all_query_arguments {}
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
  }

  # 대용량 요청 차단 규칙
  rule {
    name     = "LargeBodyProtection"
    priority = 30

    action {
      block {}
    }

    statement {
      size_constraint_statement {
        field_to_match {
          body {}
        }
        comparison_operator = "GT"
        size                = 8192 # 8KB 제한
        text_transformation {
          priority = 0
          type     = "NONE"
        }
      }
    }

    visibility_config {
      sampled_requests_enabled   = true
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.name_prefix}-LargeBodyProtection"
    }
  }

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-alb-waf"
    Environment = var.environment
    Type        = "security"
  })

  visibility_config {
    sampled_requests_enabled   = true
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.name_prefix}-ALB-WebACL"
  }
}

# WAF와 ALB 연결
resource "aws_wafv2_web_acl_association" "alb" {
  count = var.enable_waf_rate_limiting ? 1 : 0

  resource_arn = aws_lb.this.arn
  web_acl_arn  = aws_wafv2_web_acl.alb_rate_limit[0].arn

  depends_on = [
    aws_lb.this,
    aws_wafv2_web_acl.alb_rate_limit
  ]
}

# ==========================================
# WAF 로깅 설정
# ==========================================

# WAF 로그 그룹
resource "aws_cloudwatch_log_group" "waf_logs" {
  count = var.enable_waf_rate_limiting ? 1 : 0

  name              = "/aws/wafv2/${var.name_prefix}-alb"
  retention_in_days = var.waf_log_retention_days

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-alb-waf-logs"
    Environment = var.environment
    Type        = "security-logging"
  })
}

# WAF 로깅 설정
resource "aws_wafv2_web_acl_logging_configuration" "alb" {
  count = var.enable_waf_rate_limiting ? 1 : 0

  resource_arn            = aws_wafv2_web_acl.alb_rate_limit[0].arn
  log_destination_configs = [aws_cloudwatch_log_group.waf_logs[0].arn]

  # 민감한 정보 필터링
  redacted_fields {
    single_header {
      name = "authorization"
    }
  }

  redacted_fields {
    single_header {
      name = "cookie"
    }
  }

  redacted_fields {
    single_header {
      name = "x-api-key"
    }
  }

  depends_on = [
    aws_wafv2_web_acl.alb_rate_limit,
    aws_cloudwatch_log_group.waf_logs
  ]
}

# ==========================================
# CloudWatch 알람 - Rate Limiting 모니터링
# ==========================================

# WAF 차단 요청 알람
resource "aws_cloudwatch_metric_alarm" "waf_blocked_requests" {
  count = var.enable_waf_rate_limiting && var.enable_waf_monitoring ? 1 : 0

  alarm_name          = "${var.name_prefix}-alb-waf-blocked-requests"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "BlockedRequests"
  namespace           = "AWS/WAFV2"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.rate_limit_alarm_threshold
  alarm_description   = "ALB WAF에 의해 차단된 요청이 임계값을 초과했습니다"
  alarm_actions       = var.alarm_actions

  dimensions = {
    WebACL = aws_wafv2_web_acl.alb_rate_limit[0].name
    Region = data.aws_region.current.name
  }

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-alb-waf-blocked-alarm"
    Environment = var.environment
    Type        = "monitoring"
  })
}

# Rate Limiting 규칙별 알람
resource "aws_cloudwatch_metric_alarm" "waf_rate_limit_alarms" {
  for_each = var.enable_waf_rate_limiting && var.enable_waf_monitoring ? toset(["GeneralRateLimit", "BurstRateLimit"]) : toset([])

  alarm_name          = "${var.name_prefix}-alb-waf-${each.key}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "BlockedRequests"
  namespace           = "AWS/WAFV2"
  period              = "300"
  statistic           = "Sum"
  threshold           = each.key == "BurstRateLimit" ? var.rate_limit_alarm_threshold / 2 : var.rate_limit_alarm_threshold
  alarm_description   = "ALB WAF ${each.key} 규칙에 의해 차단된 요청이 임계값을 초과했습니다"
  alarm_actions       = var.alarm_actions

  dimensions = {
    WebACL = aws_wafv2_web_acl.alb_rate_limit[0].name
    Rule   = each.key
    Region = data.aws_region.current.name
  }

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-alb-waf-${each.key}-alarm"
    Environment = var.environment
    Type        = "monitoring"
  })
}

# ALB 타겟 그룹 건강성 알람
resource "aws_cloudwatch_metric_alarm" "alb_target_health" {
  count = var.enable_waf_monitoring ? 1 : 0

  alarm_name          = "${var.name_prefix}-alb-unhealthy-targets"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Average"
  threshold           = 1
  alarm_description   = "ALB 타겟 그룹의 건강한 호스트 수가 임계값 미만입니다"
  alarm_actions       = var.alarm_actions
  treat_missing_data  = "breaching"

  dimensions = {
    TargetGroup  = aws_lb_target_group.default.arn_suffix
    LoadBalancer = aws_lb.this.arn_suffix
  }

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-alb-target-health-alarm"
    Environment = var.environment
    Type        = "monitoring"
  })
}