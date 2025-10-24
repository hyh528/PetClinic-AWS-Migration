# API Gateway REST API 생성 (Spring Cloud Gateway 대체)
resource "aws_api_gateway_rest_api" "this" {
  name        = "${var.project_name}-${var.environment}-api"
  description = "PetClinic 애플리케이션용 API Gateway"

  # Regional 엔드포인트 (설계서 요구사항)
  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-api"
    Project     = var.project_name
    Environment = var.environment
    Purpose     = "마이크로서비스 API 라우팅"
    ManagedBy   = "terraform"
  }
}

# API Gateway 프록시 리소스 (모든 경로 처리)
resource "aws_api_gateway_resource" "proxy" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "{proxy+}" # 모든 하위 경로를 ALB로 프록시
}

# API Gateway 메서드 (모든 HTTP 메서드 허용)
resource "aws_api_gateway_method" "proxy_any" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.proxy.id
  http_method   = "ANY"
  authorization = "NONE" # 인증 없음 (설계서 요구사항)

  request_parameters = {
    "method.request.path.proxy" = true
  }
}

# API Gateway 통합 (ALB로 직접 프록시)
resource "aws_api_gateway_integration" "proxy_alb" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.proxy.id
  http_method             = aws_api_gateway_method.proxy_any.http_method
  type                    = "HTTP_PROXY"
  integration_http_method = "ANY"

  # ALB로 직접 연결 (Public ALB이므로 VPC Link 불필요)
  uri = "http://${var.alb_dns_name}/{proxy}"

  request_parameters = {
    "integration.request.path.proxy" = "method.request.path.proxy"
  }

  # 타임아웃 설정
  timeout_milliseconds = 29000
}

# API Gateway 배포
resource "aws_api_gateway_deployment" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  description = "Deployment for ${var.environment} stage"

  # 리소스 변경 시 자동 재배포 트리거
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.proxy.id,
      aws_api_gateway_method.proxy_any.id,
      aws_api_gateway_integration.proxy_alb.id,
      # CORS 관련 리소스도 포함
      aws_api_gateway_method.proxy_options.id,
      aws_api_gateway_integration.proxy_options.id,
    ]))
  }

  # 배포가 완료된 후 스테이지를 생성하거나 업데이트합니다.
  lifecycle {
    create_before_destroy = true
  }
}

# API Gateway 스테이지
resource "aws_api_gateway_stage" "this" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  deployment_id = aws_api_gateway_deployment.this.id
  stage_name    = var.environment
  description   = "PetClinic ${var.environment} 환경 스테이지"

  # X-Ray 트레이싱 활성화 (설계서 9.4절 요구사항)
  xray_tracing_enabled = true
/*
  # 액세스 로깅 설정 - 생성한 로그 그룹 참조
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway_logs.arn
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
*/
  # 참고: 스로틀링 설정은 aws_api_gateway_usage_plan에서 관리
  # throttle_settings는 stage에서 지원되지 않음

  # 태그
  tags = {
    Name        = "${var.project_name}-${var.environment}-stage"
    Project     = var.project_name
    Environment = var.environment
  }
}

# CORS 지원을 위한 OPTIONS 메서드 (개발 환경 필수)
resource "aws_api_gateway_method" "proxy_options" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.proxy.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

# CORS 통합 설정 (MOCK 응답)
resource "aws_api_gateway_integration" "proxy_options" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.proxy.id
  http_method = aws_api_gateway_method.proxy_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = jsonencode({
      statusCode = 200
    })
  }
}

# CORS 응답 헤더 설정
resource "aws_api_gateway_method_response" "proxy_options" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.proxy.id
  http_method = aws_api_gateway_method.proxy_options.http_method
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
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.proxy.id
  http_method = aws_api_gateway_method.proxy_options.http_method
  status_code = aws_api_gateway_method_response.proxy_options.status_code

  response_parameters = {
    # Dev 환경용 - 모든 오리진 허용 (개발 편의성 우선)
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS,POST,PUT,DELETE'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  response_templates = {
    "application/json" = ""
  }
}

# VPC Link는 제거됨 - Public ALB와 직접 통합하므로 불필요
# API Gateway → ALB → ECS 구조로 단순화

# CloudWatch Logs 그룹 (API Gateway 액세스 로그)
resource "aws_cloudwatch_log_group" "api_gateway_logs" {
  name              = "/aws/api-gateway/${var.project_name}-${var.environment}"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${var.project_name}-${var.environment}-api-gateway-logs"
    Project     = var.project_name
    Environment = var.environment
    Purpose     = "API Gateway 액세스 로그"
    ManagedBy   = "terraform"
  }
}