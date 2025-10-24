# API Gateway 모듈 - Spring Cloud Gateway 대체
# REST API 타입으로 ALB와 통합하여 마이크로서비스 라우팅 제공

# 현재 AWS 리전 정보
data "aws_region" "current" {}

# ==========================================
# 로컬 변수 정의 (DRY 원칙 적용)
# ==========================================
locals {
  # 서비스 정의 (pet-app 및 ToBe아키텍트.md 참조)
  services = {
    customers = {
      path        = "customers-service"
      parent_path = "api"
      description = "고객 및 반려동물 관리 서비스"
    }
    vets = {
      path        = "vets-service"
      parent_path = "api"
      description = "수의사 정보 관리 서비스"
    }
    visits = {
      path        = "visits-service"
      parent_path = "api"
      description = "예약 및 방문 추적 서비스"
    }
    admin = {
      path        = "admin-server"
      parent_path = "root"
      description = "관리자 서비스 (개발/디버깅용)"
    }
  }

  # GenAI 서비스 정의 (조건부)
  genai_service = var.enable_lambda_integration ? {
    genai = {
      path        = "genai"
      parent_path = "api"
      description = "AI 기반 기능 및 추천 서비스"
    }
  } : {}

  # 모든 서비스 통합
  all_services = merge(local.services, local.genai_service, var.custom_services)

  # ALB 통합 서비스 (Lambda 제외)
  alb_services = { for k, v in local.all_services : k => v if k != "genai" }

  # Lambda 통합 서비스
  lambda_services = { for k, v in local.all_services : k => v if k == "genai" }

  # 공통 설정
  common_settings = {
    timeout_ms        = var.integration_timeout_ms
    lambda_timeout_ms = var.lambda_integration_timeout_ms
  }

  # 태그 표준화
  common_tags = merge(var.tags, {
    Environment = var.environment
    Service     = "api-gateway"
    ManagedBy   = "terraform"
  })
}

# REST API 생성
resource "aws_api_gateway_rest_api" "this" {
  name        = "${var.project_name}-${var.environment}-api"
  description = "PetClinic 마이크로서비스용 API Gateway"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  # CORS 설정을 위한 바이너리 미디어 타입
  binary_media_types = ["*/*"]

  # 고급 설정
  minimum_compression_size     = var.minimum_compression_size
  api_key_source               = var.api_key_source
  disable_execute_api_endpoint = var.disable_execute_api_endpoint

  # 리소스 정책 (선택사항)
  policy = var.policy

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-api-gateway"
  })
}

# ==========================================
# API Gateway 배포 (개선된 의존성 관리)
# ==========================================

# API Gateway 배포
resource "aws_api_gateway_deployment" "this" {
  depends_on = [
    # 동적 리소스 의존성
    aws_api_gateway_resource.api,
    aws_api_gateway_resource.services,
    aws_api_gateway_resource.service_proxies,
    # 동적 메서드 의존성
    aws_api_gateway_method.service_methods,
    aws_api_gateway_method.service_proxy_methods,
    # 동적 통합 의존성
    aws_api_gateway_integration.alb_service_integrations,
    aws_api_gateway_integration.alb_service_proxy_integrations,
    aws_api_gateway_integration.lambda_service_integrations,
    aws_api_gateway_integration.lambda_service_proxy_integrations,
  ]

  rest_api_id = aws_api_gateway_rest_api.this.id

  triggers = {
    # 설정 변경 시 재배포를 위한 트리거 (개선된 해시)
    redeployment = sha1(jsonencode({
      # 서비스 설정
      services = local.all_services
      # 통합 설정
      alb_dns_name        = var.alb_dns_name
      lambda_integration  = var.enable_lambda_integration
      lambda_function_arn = var.lambda_function_invoke_arn
      # 타임아웃 설정
      timeouts = local.common_settings
      # API 설정
      api_settings = {
        compression_size = var.minimum_compression_size
        api_key_source   = var.api_key_source
        disable_endpoint = var.disable_execute_api_endpoint
      }
    }))
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ==========================================
# API Gateway 스테이지 설정 (개선된 로깅)
# ==========================================

# API Gateway 스테이지
resource "aws_api_gateway_stage" "this" {
  deployment_id = aws_api_gateway_deployment.this.id
  rest_api_id   = aws_api_gateway_rest_api.this.id
  stage_name    = var.stage_name

  # 액세스 로깅 설정
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format = jsonencode({
      requestId            = "$context.requestId"
      ip                   = "$context.identity.sourceIp"
      caller               = "$context.identity.caller"
      user                 = "$context.identity.user"
      requestTime          = "$context.requestTime"
      httpMethod           = "$context.httpMethod"
      resourcePath         = "$context.resourcePath"
      status               = "$context.status"
      protocol             = "$context.protocol"
      responseLength       = "$context.responseLength"
      integrationLatency   = "$context.integrationLatency"
      integrationStatus    = "$context.integrationStatus"
      authorizerLatency    = "$context.authorizerLatency"
      authorizerStatus     = "$context.authorizerStatus"
      errorResponseMessage = "$context.error.message"
      extendedRequestId    = "$context.extendedRequestId"
    })
  }

  # X-Ray 추적 활성화
  xray_tracing_enabled = var.enable_xray_tracing
}

# API Gateway 메서드 설정 (실행 로깅)
resource "aws_api_gateway_method_settings" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  stage_name  = aws_api_gateway_stage.this.stage_name
  method_path = "*/*"

  settings {
    logging_level      = "INFO"
    data_trace_enabled = true
    metrics_enabled    = true

    # 스로틀링 설정
    throttling_rate_limit  = var.throttle_rate_limit
    throttling_burst_limit = var.throttle_burst_limit

    # 캐싱 설정 (선택사항)
    caching_enabled = false
  }
}

# ==========================================
# CloudWatch 로깅 설정
# ==========================================

# CloudWatch 로그 그룹 (API Gateway 액세스 로그용)
resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${var.project_name}-${var.environment}-api"
  retention_in_days = var.log_retention_days

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-api-gateway-logs"
    Type = "logging"
  })
}

# CloudWatch 로그 그룹 (API Gateway 실행 로그용)
resource "aws_cloudwatch_log_group" "api_gateway_execution" {
  name              = "/aws/apigateway/${var.project_name}-${var.environment}-api-execution"
  retention_in_days = var.log_retention_days

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-api-gateway-execution-logs"
    Type = "logging"
  })
}

# ==========================================
# API 리소스 생성 (DRY 원칙 적용)
# ==========================================

# API 루트 리소스 생성
resource "aws_api_gateway_resource" "api" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "api"
}

# 서비스별 메인 리소스 생성 (동적)
resource "aws_api_gateway_resource" "services" {
  for_each = local.all_services

  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = each.value.parent_path == "api" ? aws_api_gateway_resource.api.id : aws_api_gateway_rest_api.this.root_resource_id
  path_part   = each.value.path
}

# 서비스별 프록시 리소스 생성 (동적)
resource "aws_api_gateway_resource" "service_proxies" {
  for_each = local.all_services

  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.services[each.key].id
  path_part   = "{proxy+}"
}

# ==========================================
# API 메서드 생성 (DRY 원칙 적용)
# ==========================================

# 서비스별 메인 메서드 생성 (동적)
resource "aws_api_gateway_method" "service_methods" {
  for_each = local.all_services

  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.services[each.key].id
  http_method   = "ANY"
  authorization = "NONE"
}

# 서비스별 프록시 메서드 생성 (동적)
resource "aws_api_gateway_method" "service_proxy_methods" {
  for_each = local.all_services

  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.service_proxies[each.key].id
  http_method   = "ANY"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.proxy" = true
  }
}

# ==========================================
# API 통합 설정 (DRY 원칙 적용)
# ==========================================

# ALB 통합 - 서비스별 메인 경로
resource "aws_api_gateway_integration" "alb_service_integrations" {
  for_each = local.alb_services

  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.services[each.key].id
  http_method = aws_api_gateway_method.service_methods[each.key].http_method

  integration_http_method = "ANY"
  type                    = "HTTP_PROXY"
  uri                     = each.value.parent_path == "api" ? "http://${var.alb_dns_name}/api/${each.value.path}" : "http://${var.alb_dns_name}/${each.value.path}"

  connection_type      = "INTERNET"
  timeout_milliseconds = local.common_settings.timeout_ms
}

# ALB 통합 - 서비스별 프록시 경로
resource "aws_api_gateway_integration" "alb_service_proxy_integrations" {
  for_each = local.alb_services

  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.service_proxies[each.key].id
  http_method = aws_api_gateway_method.service_proxy_methods[each.key].http_method

  integration_http_method = "ANY"
  type                    = "HTTP_PROXY"
  uri                     = each.value.parent_path == "api" ? "http://${var.alb_dns_name}/api/${each.value.path}/{proxy}" : "http://${var.alb_dns_name}/${each.value.path}/{proxy}"

  connection_type = "INTERNET"

  request_parameters = {
    "integration.request.path.proxy" = "method.request.path.proxy"
  }

  timeout_milliseconds = local.common_settings.timeout_ms
}

# Lambda 통합 - GenAI 서비스 (조건부)
resource "aws_api_gateway_integration" "lambda_service_integrations" {
  for_each = local.lambda_services

  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.services[each.key].id
  http_method = aws_api_gateway_method.service_methods[each.key].http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_function_invoke_arn

  timeout_milliseconds = local.common_settings.lambda_timeout_ms
}

# Lambda 통합 - GenAI 프록시 경로 (조건부)
resource "aws_api_gateway_integration" "lambda_service_proxy_integrations" {
  for_each = local.lambda_services

  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.service_proxies[each.key].id
  http_method = aws_api_gateway_method.service_proxy_methods[each.key].http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_function_invoke_arn

  timeout_milliseconds = local.common_settings.lambda_timeout_ms
}

# ==========================================
# CORS 설정 (DRY 원칙 적용)
# ==========================================

locals {
  # CORS 설정이 필요한 리소스들
  cors_resources = var.enable_cors ? {
    api_proxy = {
      resource_id = aws_api_gateway_resource.api.id
      description = "/api 프록시 CORS"
    }
  } : {}

  # CORS 헤더 설정
  cors_headers = {
    allow_headers = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    allow_methods = "'GET,OPTIONS,POST,PUT,DELETE'"
    allow_origin  = "'*'"
  }
}

# CORS OPTIONS 메서드 (동적 생성)
resource "aws_api_gateway_method" "cors_options" {
  for_each = local.cors_resources

  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = each.value.resource_id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

# CORS 통합 설정 (동적 생성)
resource "aws_api_gateway_integration" "cors_integrations" {
  for_each = local.cors_resources

  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = each.value.resource_id
  http_method = aws_api_gateway_method.cors_options[each.key].http_method

  type = "MOCK"

  request_templates = {
    "application/json" = jsonencode({
      statusCode = 200
    })
  }
}

# CORS 메서드 응답 (동적 생성)
resource "aws_api_gateway_method_response" "cors_method_responses" {
  for_each = local.cors_resources

  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = each.value.resource_id
  http_method = aws_api_gateway_method.cors_options[each.key].http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }

  response_models = {
    "application/json" = "Empty"
  }
}

# CORS 통합 응답 (동적 생성)
resource "aws_api_gateway_integration_response" "cors_integration_responses" {
  for_each = local.cors_resources

  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = each.value.resource_id
  http_method = aws_api_gateway_method.cors_options[each.key].http_method
  status_code = aws_api_gateway_method_response.cors_method_responses[each.key].status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = local.cors_headers.allow_headers
    "method.response.header.Access-Control-Allow-Methods" = local.cors_headers.allow_methods
    "method.response.header.Access-Control-Allow-Origin"  = local.cors_headers.allow_origin
  }

  response_templates = {
    "application/json" = ""
  }
}

# ==========================================
# API Gateway 사용량 계획 (개선된 설정)
# ==========================================

# API Gateway 사용량 계획 (선택사항)
resource "aws_api_gateway_usage_plan" "this" {
  count = var.create_usage_plan ? 1 : 0

  name        = "${var.project_name}-${var.environment}-usage-plan"
  description = "PetClinic API 사용량 계획 - ${var.environment} 환경"

  api_stages {
    api_id = aws_api_gateway_rest_api.this.id
    stage  = aws_api_gateway_stage.this.stage_name

    # 스테이지별 스로틀링 설정 (선택사항)
    throttle {
      path        = "*/*"
      rate_limit  = var.throttle_rate_limit
      burst_limit = var.throttle_burst_limit
    }
  }

  quota_settings {
    limit  = var.quota_limit
    period = var.quota_period
  }

  throttle_settings {
    rate_limit  = var.throttle_rate_limit
    burst_limit = var.throttle_burst_limit
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-api-usage-plan"
    Type = "usage-plan"
  })
}

# ==========================================
# CloudWatch 알람 (DRY 원칙 적용)
# ==========================================

locals {
  # 알람 설정 정의
  alarms = var.enable_monitoring ? {
    "4xx-error-rate" = {
      metric_name         = "4XXError"
      comparison_operator = "GreaterThanThreshold"
      threshold           = var.error_4xx_threshold
      statistic           = "Sum"
      description         = "API Gateway 4XX 에러율이 임계값을 초과했습니다"
    }
    "5xx-error-rate" = {
      metric_name         = "5XXError"
      comparison_operator = "GreaterThanThreshold"
      threshold           = var.error_5xx_threshold
      statistic           = "Sum"
      description         = "API Gateway 5XX 에러율이 임계값을 초과했습니다"
    }
    "latency" = {
      metric_name         = "Latency"
      comparison_operator = "GreaterThanThreshold"
      threshold           = var.latency_threshold
      statistic           = "Average"
      description         = "API Gateway 평균 지연시간이 임계값을 초과했습니다"
    }
    "integration-latency" = {
      metric_name         = "IntegrationLatency"
      comparison_operator = "GreaterThanThreshold"
      threshold           = var.integration_latency_threshold
      statistic           = "Average"
      description         = "API Gateway 통합 지연시간이 임계값을 초과했습니다"
    }
  } : {}

  # 공통 알람 설정
  alarm_common_settings = {
    namespace          = "AWS/ApiGateway"
    period             = "300"
    evaluation_periods = "2"
    dimensions = {
      ApiName = aws_api_gateway_rest_api.this.name
      Stage   = aws_api_gateway_stage.this.stage_name
    }
  }
}

# CloudWatch 알람 (동적 생성)
resource "aws_cloudwatch_metric_alarm" "api_alarms" {
  for_each = local.alarms

  alarm_name          = "${var.project_name}-${var.environment}-api-${each.key}"
  comparison_operator = each.value.comparison_operator
  evaluation_periods  = local.alarm_common_settings.evaluation_periods
  metric_name         = each.value.metric_name
  namespace           = local.alarm_common_settings.namespace
  period              = local.alarm_common_settings.period
  statistic           = each.value.statistic
  threshold           = each.value.threshold
  alarm_description   = each.value.description
  alarm_actions       = var.alarm_actions

  dimensions = local.alarm_common_settings.dimensions

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-api-${each.key}-alarm"
    Type = "monitoring"
  })
}

# ==========================================
# CloudWatch 대시보드 (개선된 시각화)
# ==========================================

# CloudWatch 대시보드
resource "aws_cloudwatch_dashboard" "api_gateway" {
  count = var.create_dashboard ? 1 : 0

  dashboard_name = "${var.project_name}-${var.environment}-api-gateway-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      # 요청 및 에러 메트릭
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/ApiGateway", "Count", "ApiName", aws_api_gateway_rest_api.this.name, "Stage", aws_api_gateway_stage.this.stage_name, { "label" = "총 요청 수" }],
            [".", "4XXError", ".", ".", ".", ".", { "label" = "4XX 에러" }],
            [".", "5XXError", ".", ".", ".", ".", { "label" = "5XX 에러" }]
          ]
          view    = "timeSeries"
          stacked = false
          title   = "API Gateway 요청 및 에러"
          period  = 300
          region  = data.aws_region.current.name
          yAxis = {
            left = {
              min = 0
            }
          }
        }
      },
      # 지연시간 메트릭
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/ApiGateway", "Latency", "ApiName", aws_api_gateway_rest_api.this.name, "Stage", aws_api_gateway_stage.this.stage_name, { "label" = "전체 지연시간" }],
            [".", "IntegrationLatency", ".", ".", ".", ".", { "label" = "통합 지연시간" }]
          ]
          view    = "timeSeries"
          stacked = false
          title   = "API Gateway 지연시간"
          period  = 300
          region  = data.aws_region.current.name
          yAxis = {
            left = {
              min   = 0
              label = "밀리초"
            }
          }
        }
      },
      # 에러율 메트릭 (백분율)
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/ApiGateway", "4XXError", "ApiName", aws_api_gateway_rest_api.this.name, "Stage", aws_api_gateway_stage.this.stage_name, { "id" = "e1" }],
            [".", "5XXError", ".", ".", ".", ".", { "id" = "e2" }],
            [".", "Count", ".", ".", ".", ".", { "id" = "total" }],
            [{ "expression" = "(e1 + e2) / total * 100", "label" = "전체 에러율 (%)", "id" = "error_rate" }]
          ]
          view    = "timeSeries"
          stacked = false
          title   = "API Gateway 에러율"
          period  = 300
          region  = data.aws_region.current.name
          yAxis = {
            left = {
              min   = 0
              max   = 100
              label = "백분율 (%)"
            }
          }
        }
      },
      # 서비스별 요청 분포 (가능한 경우)
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = concat(
            [["AWS/ApiGateway", "Count", "ApiName", aws_api_gateway_rest_api.this.name, "Stage", aws_api_gateway_stage.this.stage_name, { "label" = "전체 요청" }]],
            # 서비스별 메트릭 (Resource 차원이 있는 경우)
            [for service_name in keys(local.all_services) :
              ["AWS/ApiGateway", "Count", "ApiName", aws_api_gateway_rest_api.this.name, "Stage", aws_api_gateway_stage.this.stage_name, "Resource", "/${service_name}", { "label" = "${service_name} 서비스" }]
            ]
          )
          view    = "timeSeries"
          stacked = true
          title   = "서비스별 요청 분포"
          period  = 300
          region  = data.aws_region.current.name
        }
      }
    ]
  })
}