# API Gateway 모듈 - Spring Cloud Gateway 대체
# REST API 타입으로 ALB와 통합하여 마이크로서비스 라우팅 제공

# 현재 AWS 리전 정보
data "aws_region" "current" {}

# REST API 생성
resource "aws_api_gateway_rest_api" "petclinic" {
  name        = "${var.name_prefix}-api"
  description = "PetClinic 마이크로서비스용 API Gateway"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  # CORS 설정을 위한 바이너리 미디어 타입
  binary_media_types = ["*/*"]

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-api-gateway"
    Environment = var.environment
    Service     = "api-gateway"
    ManagedBy   = "terraform"
  })
}

# API Gateway 배포
resource "aws_api_gateway_deployment" "petclinic" {
  depends_on = [
    # 서비스별 메서드 및 통합
    aws_api_gateway_method.customers_any,
    aws_api_gateway_method.customers_proxy_any,
    aws_api_gateway_integration.customers_integration,
    aws_api_gateway_integration.customers_proxy_integration,
    aws_api_gateway_method.vets_any,
    aws_api_gateway_method.vets_proxy_any,
    aws_api_gateway_integration.vets_integration,
    aws_api_gateway_integration.vets_proxy_integration,
    aws_api_gateway_method.visits_any,
    aws_api_gateway_method.visits_proxy_any,
    aws_api_gateway_integration.visits_integration,
    aws_api_gateway_integration.visits_proxy_integration,
    aws_api_gateway_method.admin_any,
    aws_api_gateway_method.admin_proxy_any,
    aws_api_gateway_integration.admin_integration,
    aws_api_gateway_integration.admin_proxy_integration,
    # GenAI Lambda 통합 (조건부)
    aws_api_gateway_method.genai_any,
    aws_api_gateway_method.genai_proxy_any,
    aws_api_gateway_integration.genai_integration,
    aws_api_gateway_integration.genai_proxy_integration,
    # 기본 프록시 및 루트
    aws_api_gateway_method.proxy_any,
    aws_api_gateway_integration.alb_integration,
    aws_api_gateway_method.root_any,
    aws_api_gateway_integration.root_alb_integration
  ]

  rest_api_id = aws_api_gateway_rest_api.petclinic.id

  triggers = {
    # 설정 변경 시 재배포를 위한 트리거
    redeployment = sha1(jsonencode([
      # 서비스별 리소스
      aws_api_gateway_resource.api.id,
      aws_api_gateway_resource.customers.id,
      aws_api_gateway_resource.customers_proxy.id,
      aws_api_gateway_resource.vets.id,
      aws_api_gateway_resource.vets_proxy.id,
      aws_api_gateway_resource.visits.id,
      aws_api_gateway_resource.visits_proxy.id,
      aws_api_gateway_resource.admin.id,
      aws_api_gateway_resource.admin_proxy.id,
      # GenAI Lambda 리소스 (조건부)
      var.enable_lambda_integration ? aws_api_gateway_resource.genai[0].id : "",
      var.enable_lambda_integration ? aws_api_gateway_resource.genai_proxy[0].id : "",
      var.enable_lambda_integration ? aws_api_gateway_method.genai_any[0].id : "",
      var.enable_lambda_integration ? aws_api_gateway_integration.genai_integration[0].id : "",
      # 기본 리소스
      aws_api_gateway_resource.proxy.id,
      aws_api_gateway_method.root_any.id,
      aws_api_gateway_integration.root_alb_integration.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

# API Gateway 스테이지
resource "aws_api_gateway_stage" "petclinic" {
  deployment_id = aws_api_gateway_deployment.petclinic.id
  rest_api_id   = aws_api_gateway_rest_api.petclinic.id
  stage_name    = var.stage_name

  # 스로틀링 설정은 별도 리소스로 관리
  # throttle_settings는 aws_api_gateway_stage에서 지원되지 않음

  # 액세스 로깅 설정
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      caller         = "$context.identity.caller"
      user           = "$context.identity.user"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      resourcePath   = "$context.resourcePath"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
      responseTime   = "$context.responseTime"
      error          = "$context.error.message"
      integrationError = "$context.integration.error"
    })
  }

  # X-Ray 추적 활성화
  xray_tracing_enabled = var.enable_xray_tracing

  # tags는 aws_api_gateway_stage에서 지원되지 않음
}

# CloudWatch 로그 그룹 (API Gateway 액세스 로그용)
resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${var.name_prefix}-api"
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-api-gateway-logs"
    Environment = var.environment
    Service     = "api-gateway"
  })
}

# API 루트 리소스 생성
resource "aws_api_gateway_resource" "api" {
  rest_api_id = aws_api_gateway_rest_api.petclinic.id
  parent_id   = aws_api_gateway_rest_api.petclinic.root_resource_id
  path_part   = "api"
}

# 서비스별 리소스 생성
resource "aws_api_gateway_resource" "customers" {
  rest_api_id = aws_api_gateway_rest_api.petclinic.id
  parent_id   = aws_api_gateway_resource.api.id
  path_part   = "customers"
}

resource "aws_api_gateway_resource" "customers_proxy" {
  rest_api_id = aws_api_gateway_rest_api.petclinic.id
  parent_id   = aws_api_gateway_resource.customers.id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_resource" "vets" {
  rest_api_id = aws_api_gateway_rest_api.petclinic.id
  parent_id   = aws_api_gateway_resource.api.id
  path_part   = "vets"
}

resource "aws_api_gateway_resource" "vets_proxy" {
  rest_api_id = aws_api_gateway_rest_api.petclinic.id
  parent_id   = aws_api_gateway_resource.vets.id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_resource" "visits" {
  rest_api_id = aws_api_gateway_rest_api.petclinic.id
  parent_id   = aws_api_gateway_resource.api.id
  path_part   = "visits"
}

resource "aws_api_gateway_resource" "visits_proxy" {
  rest_api_id = aws_api_gateway_rest_api.petclinic.id
  parent_id   = aws_api_gateway_resource.visits.id
  path_part   = "{proxy+}"
}

# Admin 서비스 리소스 (개발/디버깅용)
resource "aws_api_gateway_resource" "admin" {
  rest_api_id = aws_api_gateway_rest_api.petclinic.id
  parent_id   = aws_api_gateway_rest_api.petclinic.root_resource_id
  path_part   = "admin"
}

resource "aws_api_gateway_resource" "admin_proxy" {
  rest_api_id = aws_api_gateway_rest_api.petclinic.id
  parent_id   = aws_api_gateway_resource.admin.id
  path_part   = "{proxy+}"
}

# 프록시 리소스 생성 ({proxy+}) - 기타 모든 경로용
resource "aws_api_gateway_resource" "proxy" {
  rest_api_id = aws_api_gateway_rest_api.petclinic.id
  parent_id   = aws_api_gateway_rest_api.petclinic.root_resource_id
  path_part   = "{proxy+}"
}

# 서비스별 메서드 정의
# Customers 서비스
resource "aws_api_gateway_method" "customers_any" {
  rest_api_id   = aws_api_gateway_rest_api.petclinic.id
  resource_id   = aws_api_gateway_resource.customers.id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "customers_proxy_any" {
  rest_api_id   = aws_api_gateway_rest_api.petclinic.id
  resource_id   = aws_api_gateway_resource.customers_proxy.id
  http_method   = "ANY"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.proxy" = true
  }
}

# Vets 서비스
resource "aws_api_gateway_method" "vets_any" {
  rest_api_id   = aws_api_gateway_rest_api.petclinic.id
  resource_id   = aws_api_gateway_resource.vets.id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "vets_proxy_any" {
  rest_api_id   = aws_api_gateway_rest_api.petclinic.id
  resource_id   = aws_api_gateway_resource.vets_proxy.id
  http_method   = "ANY"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.proxy" = true
  }
}

# Visits 서비스
resource "aws_api_gateway_method" "visits_any" {
  rest_api_id   = aws_api_gateway_rest_api.petclinic.id
  resource_id   = aws_api_gateway_resource.visits.id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "visits_proxy_any" {
  rest_api_id   = aws_api_gateway_rest_api.petclinic.id
  resource_id   = aws_api_gateway_resource.visits_proxy.id
  http_method   = "ANY"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.proxy" = true
  }
}

# Admin 서비스
resource "aws_api_gateway_method" "admin_any" {
  rest_api_id   = aws_api_gateway_rest_api.petclinic.id
  resource_id   = aws_api_gateway_resource.admin.id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "admin_proxy_any" {
  rest_api_id   = aws_api_gateway_rest_api.petclinic.id
  resource_id   = aws_api_gateway_resource.admin_proxy.id
  http_method   = "ANY"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.proxy" = true
  }
}

# 프록시 리소스에 대한 ANY 메서드 (기타 모든 경로)
resource "aws_api_gateway_method" "proxy_any" {
  rest_api_id   = aws_api_gateway_rest_api.petclinic.id
  resource_id   = aws_api_gateway_resource.proxy.id
  http_method   = "ANY"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.proxy" = true
  }
}

# 루트 리소스에 대한 ANY 메서드
resource "aws_api_gateway_method" "root_any" {
  rest_api_id   = aws_api_gateway_rest_api.petclinic.id
  resource_id   = aws_api_gateway_rest_api.petclinic.root_resource_id
  http_method   = "ANY"
  authorization = "NONE"
}

# 서비스별 ALB 통합 설정
# Customers 서비스 통합
resource "aws_api_gateway_integration" "customers_integration" {
  rest_api_id = aws_api_gateway_rest_api.petclinic.id
  resource_id = aws_api_gateway_resource.customers.id
  http_method = aws_api_gateway_method.customers_any.http_method

  integration_http_method = "ANY"
  type                   = "HTTP_PROXY"
  uri                    = "http://${var.alb_dns_name}/api/customers"

  connection_type = "INTERNET"
  timeout_milliseconds = var.integration_timeout_ms
}

resource "aws_api_gateway_integration" "customers_proxy_integration" {
  rest_api_id = aws_api_gateway_rest_api.petclinic.id
  resource_id = aws_api_gateway_resource.customers_proxy.id
  http_method = aws_api_gateway_method.customers_proxy_any.http_method

  integration_http_method = "ANY"
  type                   = "HTTP_PROXY"
  uri                    = "http://${var.alb_dns_name}/api/customers/{proxy}"

  connection_type = "INTERNET"

  request_parameters = {
    "integration.request.path.proxy" = "method.request.path.proxy"
  }

  timeout_milliseconds = var.integration_timeout_ms
}

# Vets 서비스 통합
resource "aws_api_gateway_integration" "vets_integration" {
  rest_api_id = aws_api_gateway_rest_api.petclinic.id
  resource_id = aws_api_gateway_resource.vets.id
  http_method = aws_api_gateway_method.vets_any.http_method

  integration_http_method = "ANY"
  type                   = "HTTP_PROXY"
  uri                    = "http://${var.alb_dns_name}/api/vets"

  connection_type = "INTERNET"
  timeout_milliseconds = var.integration_timeout_ms
}

resource "aws_api_gateway_integration" "vets_proxy_integration" {
  rest_api_id = aws_api_gateway_rest_api.petclinic.id
  resource_id = aws_api_gateway_resource.vets_proxy.id
  http_method = aws_api_gateway_method.vets_proxy_any.http_method

  integration_http_method = "ANY"
  type                   = "HTTP_PROXY"
  uri                    = "http://${var.alb_dns_name}/api/vets/{proxy}"

  connection_type = "INTERNET"

  request_parameters = {
    "integration.request.path.proxy" = "method.request.path.proxy"
  }

  timeout_milliseconds = var.integration_timeout_ms
}

# Visits 서비스 통합
resource "aws_api_gateway_integration" "visits_integration" {
  rest_api_id = aws_api_gateway_rest_api.petclinic.id
  resource_id = aws_api_gateway_resource.visits.id
  http_method = aws_api_gateway_method.visits_any.http_method

  integration_http_method = "ANY"
  type                   = "HTTP_PROXY"
  uri                    = "http://${var.alb_dns_name}/api/visits"

  connection_type = "INTERNET"
  timeout_milliseconds = var.integration_timeout_ms
}

resource "aws_api_gateway_integration" "visits_proxy_integration" {
  rest_api_id = aws_api_gateway_rest_api.petclinic.id
  resource_id = aws_api_gateway_resource.visits_proxy.id
  http_method = aws_api_gateway_method.visits_proxy_any.http_method

  integration_http_method = "ANY"
  type                   = "HTTP_PROXY"
  uri                    = "http://${var.alb_dns_name}/api/visits/{proxy}"

  connection_type = "INTERNET"

  request_parameters = {
    "integration.request.path.proxy" = "method.request.path.proxy"
  }

  timeout_milliseconds = var.integration_timeout_ms
}

# Admin 서비스 통합
resource "aws_api_gateway_integration" "admin_integration" {
  rest_api_id = aws_api_gateway_rest_api.petclinic.id
  resource_id = aws_api_gateway_resource.admin.id
  http_method = aws_api_gateway_method.admin_any.http_method

  integration_http_method = "ANY"
  type                   = "HTTP_PROXY"
  uri                    = "http://${var.alb_dns_name}/admin"

  connection_type = "INTERNET"
  timeout_milliseconds = var.integration_timeout_ms
}

resource "aws_api_gateway_integration" "admin_proxy_integration" {
  rest_api_id = aws_api_gateway_rest_api.petclinic.id
  resource_id = aws_api_gateway_resource.admin_proxy.id
  http_method = aws_api_gateway_method.admin_proxy_any.http_method

  integration_http_method = "ANY"
  type                   = "HTTP_PROXY"
  uri                    = "http://${var.alb_dns_name}/admin/{proxy}"

  connection_type = "INTERNET"

  request_parameters = {
    "integration.request.path.proxy" = "method.request.path.proxy"
  }

  timeout_milliseconds = var.integration_timeout_ms
}

# GenAI Lambda 서비스 리소스 및 통합 (Lambda + Bedrock)
resource "aws_api_gateway_resource" "genai" {
  count = var.enable_lambda_integration ? 1 : 0

  rest_api_id = aws_api_gateway_rest_api.petclinic.id
  parent_id   = aws_api_gateway_resource.api.id
  path_part   = "genai"
}

resource "aws_api_gateway_resource" "genai_proxy" {
  count = var.enable_lambda_integration ? 1 : 0

  rest_api_id = aws_api_gateway_rest_api.petclinic.id
  parent_id   = aws_api_gateway_resource.genai[0].id
  path_part   = "{proxy+}"
}

# GenAI Lambda 서비스 메서드
resource "aws_api_gateway_method" "genai_any" {
  count = var.enable_lambda_integration ? 1 : 0

  rest_api_id   = aws_api_gateway_rest_api.petclinic.id
  resource_id   = aws_api_gateway_resource.genai[0].id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "genai_proxy_any" {
  count = var.enable_lambda_integration ? 1 : 0

  rest_api_id   = aws_api_gateway_rest_api.petclinic.id
  resource_id   = aws_api_gateway_resource.genai_proxy[0].id
  http_method   = "ANY"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.proxy" = true
  }
}

# GenAI Lambda 통합
resource "aws_api_gateway_integration" "genai_integration" {
  count = var.enable_lambda_integration ? 1 : 0

  rest_api_id = aws_api_gateway_rest_api.petclinic.id
  resource_id = aws_api_gateway_resource.genai[0].id
  http_method = aws_api_gateway_method.genai_any[0].http_method

  integration_http_method = "POST"
  type                   = "AWS_PROXY"
  uri                    = var.lambda_function_invoke_arn

  timeout_milliseconds = var.lambda_integration_timeout_ms
}

resource "aws_api_gateway_integration" "genai_proxy_integration" {
  count = var.enable_lambda_integration ? 1 : 0

  rest_api_id = aws_api_gateway_rest_api.petclinic.id
  resource_id = aws_api_gateway_resource.genai_proxy[0].id
  http_method = aws_api_gateway_method.genai_proxy_any[0].http_method

  integration_http_method = "POST"
  type                   = "AWS_PROXY"
  uri                    = var.lambda_function_invoke_arn

  timeout_milliseconds = var.lambda_integration_timeout_ms
}

# GenAI Lambda CORS 설정
resource "aws_api_gateway_method" "genai_options" {
  count = var.enable_cors && var.enable_lambda_integration ? 1 : 0

  rest_api_id   = aws_api_gateway_rest_api.petclinic.id
  resource_id   = aws_api_gateway_resource.genai[0].id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "genai_options" {
  count = var.enable_cors && var.enable_lambda_integration ? 1 : 0

  rest_api_id = aws_api_gateway_rest_api.petclinic.id
  resource_id = aws_api_gateway_resource.genai[0].id
  http_method = aws_api_gateway_method.genai_options[0].http_method

  type = "MOCK"

  request_templates = {
    "application/json" = jsonencode({
      statusCode = 200
    })
  }
}

resource "aws_api_gateway_method_response" "genai_options" {
  count = var.enable_cors && var.enable_lambda_integration ? 1 : 0

  rest_api_id = aws_api_gateway_rest_api.petclinic.id
  resource_id = aws_api_gateway_resource.genai[0].id
  http_method = aws_api_gateway_method.genai_options[0].http_method
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

resource "aws_api_gateway_integration_response" "genai_options" {
  count = var.enable_cors && var.enable_lambda_integration ? 1 : 0

  rest_api_id = aws_api_gateway_rest_api.petclinic.id
  resource_id = aws_api_gateway_resource.genai[0].id
  http_method = aws_api_gateway_method.genai_options[0].http_method
  status_code = aws_api_gateway_method_response.genai_options[0].status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS,POST,PUT,DELETE'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  response_templates = {
    "application/json" = ""
  }
}

# ALB 통합 설정 (프록시 리소스) - 기타 모든 경로
resource "aws_api_gateway_integration" "alb_integration" {
  rest_api_id = aws_api_gateway_rest_api.petclinic.id
  resource_id = aws_api_gateway_resource.proxy.id
  http_method = aws_api_gateway_method.proxy_any.http_method

  integration_http_method = "ANY"
  type                   = "HTTP_PROXY"
  uri                    = "http://${var.alb_dns_name}/{proxy}"

  connection_type = "INTERNET"

  request_parameters = {
    "integration.request.path.proxy" = "method.request.path.proxy"
  }

  timeout_milliseconds = var.integration_timeout_ms
}

# ALB 통합 설정 (루트 리소스)
resource "aws_api_gateway_integration" "root_alb_integration" {
  rest_api_id = aws_api_gateway_rest_api.petclinic.id
  resource_id = aws_api_gateway_rest_api.petclinic.root_resource_id
  http_method = aws_api_gateway_method.root_any.http_method

  integration_http_method = "ANY"
  type                   = "HTTP_PROXY"
  uri                    = "http://${var.alb_dns_name}/"

  connection_type = "INTERNET"

  timeout_milliseconds = var.integration_timeout_ms
}

# CORS 설정을 위한 OPTIONS 메서드 (프록시 리소스)
resource "aws_api_gateway_method" "proxy_options" {
  count = var.enable_cors ? 1 : 0

  rest_api_id   = aws_api_gateway_rest_api.petclinic.id
  resource_id   = aws_api_gateway_resource.proxy.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

# CORS 통합 설정
resource "aws_api_gateway_integration" "proxy_options" {
  count = var.enable_cors ? 1 : 0

  rest_api_id = aws_api_gateway_rest_api.petclinic.id
  resource_id = aws_api_gateway_resource.proxy.id
  http_method = aws_api_gateway_method.proxy_options[0].http_method

  type = "MOCK"

  request_templates = {
    "application/json" = jsonencode({
      statusCode = 200
    })
  }
}

# CORS 응답 설정
resource "aws_api_gateway_method_response" "proxy_options" {
  count = var.enable_cors ? 1 : 0

  rest_api_id = aws_api_gateway_rest_api.petclinic.id
  resource_id = aws_api_gateway_resource.proxy.id
  http_method = aws_api_gateway_method.proxy_options[0].http_method
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

# CORS 통합 응답 설정
resource "aws_api_gateway_integration_response" "proxy_options" {
  count = var.enable_cors ? 1 : 0

  rest_api_id = aws_api_gateway_rest_api.petclinic.id
  resource_id = aws_api_gateway_resource.proxy.id
  http_method = aws_api_gateway_method.proxy_options[0].http_method
  status_code = aws_api_gateway_method_response.proxy_options[0].status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS,POST,PUT,DELETE'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  response_templates = {
    "application/json" = ""
  }
}

# API Gateway 사용량 계획 (선택사항)
resource "aws_api_gateway_usage_plan" "petclinic" {
  count = var.create_usage_plan ? 1 : 0

  name         = "${var.name_prefix}-usage-plan"
  description  = "PetClinic API 사용량 계획"

  api_stages {
    api_id = aws_api_gateway_rest_api.petclinic.id
    stage  = aws_api_gateway_stage.petclinic.stage_name
  }

  quota_settings {
    limit  = var.quota_limit
    period = var.quota_period
  }

  throttle_settings {
    rate_limit  = var.throttle_rate_limit
    burst_limit = var.throttle_burst_limit
  }

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-api-usage-plan"
    Environment = var.environment
  })
}

# CloudWatch 알람 - 4XX 에러율
resource "aws_cloudwatch_metric_alarm" "api_4xx_error_rate" {
  count = var.enable_monitoring ? 1 : 0

  alarm_name          = "${var.name_prefix}-api-4xx-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "4XXError"
  namespace           = "AWS/ApiGateway"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.error_4xx_threshold
  alarm_description   = "API Gateway 4XX 에러율이 임계값을 초과했습니다"
  alarm_actions       = var.alarm_actions

  dimensions = {
    ApiName   = aws_api_gateway_rest_api.petclinic.name
    Stage     = aws_api_gateway_stage.petclinic.stage_name
  }

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-api-4xx-alarm"
    Environment = var.environment
    Type        = "monitoring"
  })
}

# CloudWatch 알람 - 5XX 에러율
resource "aws_cloudwatch_metric_alarm" "api_5xx_error_rate" {
  count = var.enable_monitoring ? 1 : 0

  alarm_name          = "${var.name_prefix}-api-5xx-error-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "5XXError"
  namespace           = "AWS/ApiGateway"
  period              = "300"
  statistic           = "Sum"
  threshold           = var.error_5xx_threshold
  alarm_description   = "API Gateway 5XX 에러율이 임계값을 초과했습니다"
  alarm_actions       = var.alarm_actions

  dimensions = {
    ApiName   = aws_api_gateway_rest_api.petclinic.name
    Stage     = aws_api_gateway_stage.petclinic.stage_name
  }

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-api-5xx-alarm"
    Environment = var.environment
    Type        = "monitoring"
  })
}

# CloudWatch 알람 - 지연시간
resource "aws_cloudwatch_metric_alarm" "api_latency" {
  count = var.enable_monitoring ? 1 : 0

  alarm_name          = "${var.name_prefix}-api-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Latency"
  namespace           = "AWS/ApiGateway"
  period              = "300"
  statistic           = "Average"
  threshold           = var.latency_threshold
  alarm_description   = "API Gateway 평균 지연시간이 임계값을 초과했습니다"
  alarm_actions       = var.alarm_actions

  dimensions = {
    ApiName   = aws_api_gateway_rest_api.petclinic.name
    Stage     = aws_api_gateway_stage.petclinic.stage_name
  }

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-api-latency-alarm"
    Environment = var.environment
    Type        = "monitoring"
  })
}

# CloudWatch 알람 - 통합 지연시간
resource "aws_cloudwatch_metric_alarm" "api_integration_latency" {
  count = var.enable_monitoring ? 1 : 0

  alarm_name          = "${var.name_prefix}-api-integration-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "IntegrationLatency"
  namespace           = "AWS/ApiGateway"
  period              = "300"
  statistic           = "Average"
  threshold           = var.integration_latency_threshold
  alarm_description   = "API Gateway 통합 지연시간이 임계값을 초과했습니다"
  alarm_actions       = var.alarm_actions

  dimensions = {
    ApiName   = aws_api_gateway_rest_api.petclinic.name
    Stage     = aws_api_gateway_stage.petclinic.stage_name
  }

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-api-integration-latency-alarm"
    Environment = var.environment
    Type        = "monitoring"
  })
}

# CloudWatch 대시보드
resource "aws_cloudwatch_dashboard" "api_gateway" {
  count = var.create_dashboard ? 1 : 0

  dashboard_name = "${var.name_prefix}-api-gateway-dashboard"

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
            ["AWS/ApiGateway", "Count", "ApiName", aws_api_gateway_rest_api.petclinic.name, "Stage", aws_api_gateway_stage.petclinic.stage_name],
            [".", "4XXError", ".", ".", ".", "."],
            [".", "5XXError", ".", ".", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          title   = "API Gateway 요청 및 에러"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/ApiGateway", "Latency", "ApiName", aws_api_gateway_rest_api.petclinic.name, "Stage", aws_api_gateway_stage.petclinic.stage_name],
            [".", "IntegrationLatency", ".", ".", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          title   = "API Gateway 지연시간"
          period  = 300
          yAxis = {
            left = {
              min = 0
            }
          }
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/ApiGateway", "CacheHitCount", "ApiName", aws_api_gateway_rest_api.petclinic.name, "Stage", aws_api_gateway_stage.petclinic.stage_name],
            [".", "CacheMissCount", ".", ".", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          title   = "API Gateway 캐시 성능"
          period  = 300
        }
      }
    ]
  })

  # tags는 aws_cloudwatch_dashboard에서 지원되지 않음
}