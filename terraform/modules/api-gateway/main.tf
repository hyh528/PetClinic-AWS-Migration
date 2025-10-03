# API Gateway REST API 생성
resource "aws_api_gateway_rest_api" "this" {
  # API Gateway의 이름입니다.
  name        = "${var.project_name}-${var.environment}-api"
  # API Gateway의 설명입니다.
  description = "API Gateway for PetClinic application"
  # 엔드포인트 유형을 Regional로 설정합니다.
  endpoint_configuration {
    types = ["REGIONAL"]
  }

  # API Gateway 태그입니다.
  tags = {
    Name        = "${var.project_name}-${var.environment}-api"
    Project     = var.project_name
    Environment = var.environment
  }
}

# API Gateway 리소스 (루트 경로)
resource "aws_api_gateway_resource" "root" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "{proxy+}" # 모든 하위 경로를 처리하기 위한 프록시 리소스
}

# API Gateway 메서드 (ANY 메서드)
resource "aws_api_gateway_method" "proxy_any" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.root.id
  http_method   = "ANY"
  # 인증 유형입니다 (NONE은 인증 없음).
  authorization = "NONE"
}

# API Gateway 통합 (ALB로 프록시 통합)
resource "aws_api_gateway_integration" "proxy_alb" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.root.id
  http_method             = aws_api_gateway_method.proxy_any.http_method
  type                    = "HTTP_PROXY"
  integration_http_method = "ANY"
  # 통합 엔드포인트 URI입니다. ALB의 DNS 이름을 사용합니다.
  # 이 값은 var.alb_dns_name 변수로 받아올 것입니다.
  uri                     = "http://${var.alb_dns_name}/{proxy}"
  request_parameters = {
    "integration.request.path.proxy" = "method.request.path.proxy"
  }
  connection_type         = "VPC_LINK"
  connection_id           = var.vpc_link_id
}

# API Gateway 배포
resource "aws_api_gateway_deployment" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  description = "Deployment for ${var.environment} stage"

  # 통합 리소스가 변경될 때마다 배포를 다시 하도록 트리거합니다.
  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.root.id,
      aws_api_gateway_method.proxy_any.id,
      aws_api_gateway_integration.proxy_alb.id,
    ]))
  }

  # 배포가 완료된 후 스테이지를 생성하거나 업데이트합니다.
  lifecycle {
    create_before_destroy = true
  }
}

# API Gateway 스테이지
resource "aws_api_gateway_stage" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  deployment_id = aws_api_gateway_deployment.this.id
  stage_name    = var.environment
  description   = "PetClinic ${var.environment} stage"

  # 스로틀링 설정 (var.throttling_rate와 var.throttling_burst 변수 사용)
  xray_tracing_enabled = true # X-Ray 트레이싱 활성화
  access_log_settings {
    destination_arn = var.api_gateway_log_group_arn # CloudWatch Logs 그룹 ARN
    format          = jsonencode({
      requestId               = "$context.requestId"
      ip                      = "$context.identity.sourceIp"
      caller                  = "$context.identity.caller"
      user                    = "$context.identity.user"
      requestTime             = "$context.requestTime"
      httpMethod              = "$context.httpMethod"
      resourcePath            = "$context.resourcePath"
      status                  = "$context.status"
      protocol                = "$context.protocol"
      responseLength          = "$context.responseLength"
      integrationLatency      = "$context.integrationLatency"
      integrationStatus       = "$context.integrationStatus"
      authorizerLatency       = "$context.authorizerLatency"
      authorizerStatus        = "$context.authorizerStatus"
      errorResponseMessage    = "$context.error.message"
      extendedRequestId       = "$context.extendedRequestId"
    })
  }

  # 스로틀링 설정 (현재 Terraform 버전/Provider 호환성 문제로 임시 주석 처리됨)
  # 이 블록을 주석 처리하는 것은 'terraform plan' 오류 진단을 위한 임시 조치이며,
  # 스로틀링 기능이 비활성화되므로 프로덕션 환경에서는 반드시 재활성화 및 검토가 필요합니다.
  # throttle_settings {
  #   rate_limit  = var.throttling_rate
  #   burst_limit = var.throttling_burst
  # }

  # 태그
  tags = {
    Name        = "${var.project_name}-${var.environment}-stage"
    Project     = var.project_name
    Environment = var.environment
  }
}

# API Gateway VPC 링크 (ALB 통합을 위해 필요)
# 이 리소스는 ALB가 속한 VPC와 API Gateway를 연결합니다.
resource "aws_api_gateway_vpc_link" "this" {
  # VPC 링크의 이름입니다.
  name        = "${var.project_name}-${var.environment}-vpc-link"
  # VPC 링크의 설명입니다.
  description = "VPC Link for PetClinic ALB integration"
  # 대상 로드 밸런서의 ARN 목록입니다.
  # 이 값은 var.target_nlb_arns 변수로 받아올 것입니다。
  target_arns = [var.target_nlb_arn]

  # 태그
  tags = {
    Name        = "${var.project_name}-${var.environment}-vpc-link"
    Project     = var.project_name
    Environment = var.environment
  }
}

# CloudWatch Logs 그룹 (API Gateway 액세스 로그용)
resource "aws_cloudwatch_log_group" "api_gateway_logs" {
  # 로그 그룹 이름입니다.
  name              = "/aws/api-gateway/${aws_api_gateway_rest_api.this.name}/${aws_api_gateway_stage.this.stage_name}"
  # 로그 보존 기간 (일)입니다.
  retention_in_days = 7

  # 태그
  tags = {
    Name        = "${var.project_name}-${var.environment}-api-gateway-logs"
    Project     = var.project_name
    Environment = var.environment
  }
}