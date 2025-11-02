# API Gateway 모듈 - Spring Cloud Gateway 대체
# REST API 타입으로 ALB와 통합하여 마이크로서비스 라우팅 제공

# 현재 AWS 리전 정보
data "aws_region" "current" {}

# ==========================================
# 로컬 변수 정의 (DRY 원칙 적용)
# ==========================================
locals {
  # 서비스 정의 (중복 제거를 위한 단일 소스)
  services = {
    customers = {
      path        = "customers"
      parent_path = "api"
      description = "고객 및 반려동물 관리 서비스"
    }
    vets = {
      path        = "vets"
      parent_path = "api"
      description = "수의사 정보 관리 서비스"
    }
    visits = {
      path        = "visits"
      parent_path = "api"
      description = "예약 및 방문 추적 서비스"
    }
    admin = {
      path        = "admin"
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
  all_services = merge(local.services, local.genai_service)

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

  # CORS 설정이 필요한 리소스들 (모든 서비스에 CORS 추가)
  cors_resources = merge(
    # 서비스별 메인 리소스
    { for k, v in local.all_services : "service_${k}" => {
      resource_id = aws_api_gateway_resource.services[k].id
      description = "${k} 서비스 CORS"
    } },
    # 서비스별 프록시 리소스
    { for k, v in local.all_services : "proxy_${k}" => {
      resource_id = aws_api_gateway_resource.service_proxies[k].id
      description = "${k} 프록시 CORS"
    } },
    # API 루트 리소스 (CORS 추가)
    var.enable_cors ? {
      api_root = {
        resource_id = aws_api_gateway_resource.api.id
        description = "API 루트 CORS"
      }
    } : {},
    # 전역 프록시
    var.enable_cors ? {
      global_proxy = {
        resource_id = aws_api_gateway_resource.global_proxy.id
        description = "전역 프록시 CORS"
      }
    } : {}
  )

  # CORS 헤더 설정
  cors_headers = {
    allow_headers = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    allow_methods = "'GET,OPTIONS,POST,PUT,DELETE'"
    allow_origin  = "'*'"
  }

}

# ==========================================
# API Gateway 기본 리소스
# ==========================================

# REST API 생성
resource "aws_api_gateway_rest_api" "petclinic" {
  name        = "${var.name_prefix}-api"
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
    Name = "${var.name_prefix}-api-gateway"
  })
}

# ==========================================
# API 리소스 생성 (DRY 원칙 적용)
# ==========================================

# API 루트 리소스 생성
resource "aws_api_gateway_resource" "api" {
  rest_api_id = aws_api_gateway_rest_api.petclinic.id
  parent_id   = aws_api_gateway_rest_api.petclinic.root_resource_id
  path_part   = "api"
}

# 서비스별 메인 리소스 생성 (동적)
resource "aws_api_gateway_resource" "services" {
  for_each = local.all_services

  rest_api_id = aws_api_gateway_rest_api.petclinic.id
  parent_id   = each.value.parent_path == "api" ? aws_api_gateway_resource.api.id : aws_api_gateway_rest_api.petclinic.root_resource_id
  path_part   = each.value.path
}

# 고객별 하위 리소스 생성 (owners, pets 등)
resource "aws_api_gateway_resource" "customer_owners" {
  rest_api_id = aws_api_gateway_rest_api.petclinic.id
  parent_id   = aws_api_gateway_resource.services["customers"].id
  path_part   = "owners"
}

resource "aws_api_gateway_resource" "customer_owners_id" {
  rest_api_id = aws_api_gateway_rest_api.petclinic.id
  parent_id   = aws_api_gateway_resource.customer_owners.id
  path_part   = "{ownerId}"
}

# 고객 정보 조회용 메서드 (GET /api/customers/owners/{ownerId})
resource "aws_api_gateway_method" "customer_owners_id_get" {
  rest_api_id   = aws_api_gateway_rest_api.petclinic.id
  resource_id   = aws_api_gateway_resource.customer_owners_id.id
  http_method   = "GET"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.ownerId" = true
  }
}

# 고객 정보 조회용 통합 (GET /api/customers/owners/{ownerId})
resource "aws_api_gateway_integration" "customer_owners_id_get_integration" {
  rest_api_id = aws_api_gateway_rest_api.petclinic.id
  resource_id = aws_api_gateway_resource.customer_owners_id.id
  http_method = aws_api_gateway_method.customer_owners_id_get.http_method

  integration_http_method = "GET"
  type                    = "HTTP_PROXY"
  uri                     = "http://${var.alb_dns_name}/api/customers/{ownerId}"

  connection_type = "INTERNET"

  request_parameters = {
    "integration.request.path.ownerId" = "method.request.path.ownerId"
  }

  timeout_milliseconds = local.common_settings.timeout_ms
}

resource "aws_api_gateway_resource" "customer_owners_pets" {
  rest_api_id = aws_api_gateway_rest_api.petclinic.id
  parent_id   = aws_api_gateway_resource.customer_owners_id.id
  path_part   = "pets"
}

resource "aws_api_gateway_resource" "customer_owners_pets_id" {
  rest_api_id = aws_api_gateway_rest_api.petclinic.id
  parent_id   = aws_api_gateway_resource.customer_owners_pets.id
  path_part   = "{petId}"
}

# 서비스별 프록시 리소스 생성 (동적)
resource "aws_api_gateway_resource" "service_proxies" {
  for_each = local.all_services

  rest_api_id = aws_api_gateway_rest_api.petclinic.id
  parent_id   = aws_api_gateway_resource.services[each.key].id
  path_part   = "{proxy+}"
}

# 전역 프록시 리소스 (기타 모든 경로용)
resource "aws_api_gateway_resource" "global_proxy" {
  rest_api_id = aws_api_gateway_rest_api.petclinic.id
  parent_id   = aws_api_gateway_rest_api.petclinic.root_resource_id
  path_part   = "{proxy+}"
}

# ==========================================
# API 메서드 생성 (DRY 원칙 적용)
# ==========================================

# 서비스별 메인 메서드 생성 (동적)
resource "aws_api_gateway_method" "service_methods" {
  for_each = local.all_services

  rest_api_id   = aws_api_gateway_rest_api.petclinic.id
  resource_id   = aws_api_gateway_resource.services[each.key].id
  http_method   = "ANY"
  authorization = "NONE"
}

# 고객 owners 메서드 생성
resource "aws_api_gateway_method" "customer_owners_method" {
  rest_api_id   = aws_api_gateway_rest_api.petclinic.id
  resource_id   = aws_api_gateway_resource.customer_owners.id
  http_method   = "ANY"
  authorization = "NONE"
}

# 고객 owners/{ownerId} 메서드 생성
resource "aws_api_gateway_method" "customer_owners_id_method" {
  rest_api_id   = aws_api_gateway_rest_api.petclinic.id
  resource_id   = aws_api_gateway_resource.customer_owners_id.id
  http_method   = "ANY"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.ownerId" = true
  }
}

# 고객 owners/{ownerId}/pets 메서드 생성
resource "aws_api_gateway_method" "customer_owners_pets_method" {
  rest_api_id   = aws_api_gateway_rest_api.petclinic.id
  resource_id   = aws_api_gateway_resource.customer_owners_pets.id
  http_method   = "ANY"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.ownerId" = true
  }
}

# 고객 owners/{ownerId}/pets/{petId} 메서드 생성
resource "aws_api_gateway_method" "customer_owners_pets_id_method" {
  rest_api_id   = aws_api_gateway_rest_api.petclinic.id
  resource_id   = aws_api_gateway_resource.customer_owners_pets_id.id
  http_method   = "ANY"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.ownerId" = true
    "method.request.path.petId"   = true
  }
}

# 서비스별 프록시 메서드 생성 (동적)
resource "aws_api_gateway_method" "service_proxy_methods" {
  for_each = local.all_services

  rest_api_id   = aws_api_gateway_rest_api.petclinic.id
  resource_id   = aws_api_gateway_resource.service_proxies[each.key].id
  http_method   = "ANY"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.proxy" = true
  }
}

# 전역 프록시 메서드 (기타 모든 경로)
resource "aws_api_gateway_method" "global_proxy_method" {
  rest_api_id   = aws_api_gateway_rest_api.petclinic.id
  resource_id   = aws_api_gateway_resource.global_proxy.id
  http_method   = "ANY"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.proxy" = true
  }
}

# 루트 메서드
resource "aws_api_gateway_method" "root_method" {
  rest_api_id   = aws_api_gateway_rest_api.petclinic.id
  resource_id   = aws_api_gateway_rest_api.petclinic.root_resource_id
  http_method   = "ANY"
  authorization = "NONE"
}

# ==========================================
# API 통합 설정 (DRY 원칙 적용)
# ==========================================

# ALB 통합 - 서비스별 메인 경로
resource "aws_api_gateway_integration" "alb_service_integrations" {
  for_each = local.alb_services

  rest_api_id = aws_api_gateway_rest_api.petclinic.id
  resource_id = aws_api_gateway_resource.services[each.key].id
  http_method = aws_api_gateway_method.service_methods[each.key].http_method

  integration_http_method = "ANY"
  type                    = "HTTP_PROXY"
  uri                     = each.value.parent_path == "api" ? "http://${var.alb_dns_name}/${each.value.parent_path}/${each.value.path}" : "http://${var.alb_dns_name}/${each.value.path}"

  connection_type      = "INTERNET"
  timeout_milliseconds = local.common_settings.timeout_ms
}

# ALB 통합 - 고객 owners 경로
resource "aws_api_gateway_integration" "customer_owners_integration" {
  rest_api_id = aws_api_gateway_rest_api.petclinic.id
  resource_id = aws_api_gateway_resource.customer_owners.id
  http_method = aws_api_gateway_method.customer_owners_method.http_method

  integration_http_method = "ANY"
  type                    = "HTTP_PROXY"
  uri                     = "http://${var.alb_dns_name}/api/customers/owners"

  connection_type      = "INTERNET"
  timeout_milliseconds = local.common_settings.timeout_ms
}

# ALB 통합 - 고객 owners/{ownerId} 경로
resource "aws_api_gateway_integration" "customer_owners_id_integration" {
  rest_api_id = aws_api_gateway_rest_api.petclinic.id
  resource_id = aws_api_gateway_resource.customer_owners_id.id
  http_method = aws_api_gateway_method.customer_owners_id_method.http_method

  integration_http_method = "ANY"
  type                    = "HTTP_PROXY"
  uri                     = "http://${var.alb_dns_name}/api/customers/owners/{ownerId}"

  connection_type = "INTERNET"

  request_parameters = {
    "integration.request.path.ownerId" = "method.request.path.ownerId"
  }

  timeout_milliseconds = local.common_settings.timeout_ms
}

# ALB 통합 - 고객 owners/{ownerId}/pets 경로
resource "aws_api_gateway_integration" "customer_owners_pets_integration" {
  rest_api_id = aws_api_gateway_rest_api.petclinic.id
  resource_id = aws_api_gateway_resource.customer_owners_pets.id
  http_method = aws_api_gateway_method.customer_owners_pets_method.http_method

  integration_http_method = "ANY"
  type                    = "HTTP_PROXY"
  uri                     = "http://${var.alb_dns_name}/api/customers/owners/{ownerId}/pets"

  connection_type = "INTERNET"

  request_parameters = {
    "integration.request.path.ownerId" = "method.request.path.ownerId"
  }

  timeout_milliseconds = local.common_settings.timeout_ms
}

# ALB 통합 - 고객 owners/{ownerId}/pets/{petId} 경로
resource "aws_api_gateway_integration" "customer_owners_pets_id_integration" {
  rest_api_id = aws_api_gateway_rest_api.petclinic.id
  resource_id = aws_api_gateway_resource.customer_owners_pets_id.id
  http_method = aws_api_gateway_method.customer_owners_pets_id_method.http_method

  integration_http_method = "ANY"
  type                    = "HTTP_PROXY"
  uri                     = "http://${var.alb_dns_name}/api/customers/owners/{ownerId}/pets/{petId}"

  connection_type = "INTERNET"

  request_parameters = {
    "integration.request.path.ownerId" = "method.request.path.ownerId"
    "integration.request.path.petId"   = "method.request.path.petId"
  }

  timeout_milliseconds = local.common_settings.timeout_ms
}

# ALB 통합 - 서비스별 프록시 경로
resource "aws_api_gateway_integration" "alb_service_proxy_integrations" {
  for_each = local.alb_services

  rest_api_id = aws_api_gateway_rest_api.petclinic.id
  resource_id = aws_api_gateway_resource.service_proxies[each.key].id
  http_method = aws_api_gateway_method.service_proxy_methods[each.key].http_method

  integration_http_method = "ANY"
  type                    = "HTTP_PROXY"
  uri                     = each.value.parent_path == "api" ? "http://${var.alb_dns_name}/${each.value.parent_path}/${each.value.path}/{proxy}" : "http://${var.alb_dns_name}/${each.value.path}/{proxy}"

  connection_type = "INTERNET"

  request_parameters = {
    "integration.request.path.proxy" = "method.request.path.proxy"
  }

  timeout_milliseconds = local.common_settings.timeout_ms
}

# Lambda 통합 - GenAI 서비스 (조건부)
resource "aws_api_gateway_integration" "lambda_service_integrations" {
  for_each = local.lambda_services

  rest_api_id = aws_api_gateway_rest_api.petclinic.id
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

  rest_api_id = aws_api_gateway_rest_api.petclinic.id
  resource_id = aws_api_gateway_resource.service_proxies[each.key].id
  http_method = aws_api_gateway_method.service_proxy_methods[each.key].http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = var.lambda_function_invoke_arn

  timeout_milliseconds = local.common_settings.lambda_timeout_ms
}

# 전역 통합 설정
# 전역 프록시 통합 (기타 모든 경로)
resource "aws_api_gateway_integration" "global_proxy_integration" {
  rest_api_id = aws_api_gateway_rest_api.petclinic.id
  resource_id = aws_api_gateway_resource.global_proxy.id
  http_method = aws_api_gateway_method.global_proxy_method.http_method

  integration_http_method = "ANY"
  type                    = "HTTP_PROXY"
  uri                     = "http://${var.alb_dns_name}/{proxy}"

  connection_type = "INTERNET"

  request_parameters = {
    "integration.request.path.proxy" = "method.request.path.proxy"
  }

  timeout_milliseconds = local.common_settings.timeout_ms
}

# 루트 통합
resource "aws_api_gateway_integration" "root_integration" {
  rest_api_id = aws_api_gateway_rest_api.petclinic.id
  resource_id = aws_api_gateway_rest_api.petclinic.root_resource_id
  http_method = aws_api_gateway_method.root_method.http_method

  integration_http_method = "ANY"
  type                    = "HTTP_PROXY"
  uri                     = "http://${var.alb_dns_name}/"

  connection_type      = "INTERNET"
  timeout_milliseconds = local.common_settings.timeout_ms
}


# ==========================================
# API Gateway 배포 및 스테이지 설정
# ==========================================

# API Gateway 배포
resource "aws_api_gateway_deployment" "petclinic" {
  depends_on = [
    # 동적 리소스 의존성
    aws_api_gateway_resource.api,
    aws_api_gateway_resource.services,
    aws_api_gateway_resource.service_proxies,
    aws_api_gateway_resource.global_proxy,
    aws_api_gateway_resource.customer_owners,
    aws_api_gateway_resource.customer_owners_id,
    aws_api_gateway_resource.customer_owners_pets,
    aws_api_gateway_resource.customer_owners_pets_id,
    # 동적 메서드 의존성
    aws_api_gateway_method.service_methods,
    aws_api_gateway_method.service_proxy_methods,
    aws_api_gateway_method.global_proxy_method,
    aws_api_gateway_method.root_method,
    aws_api_gateway_method.customer_owners_method,
    aws_api_gateway_method.customer_owners_id_method,
    aws_api_gateway_method.customer_owners_id_get,
    aws_api_gateway_method.customer_owners_pets_method,
    aws_api_gateway_method.customer_owners_pets_id_method,
    # 동적 통합 의존성
    aws_api_gateway_integration.alb_service_integrations,
    aws_api_gateway_integration.alb_service_proxy_integrations,
    aws_api_gateway_integration.lambda_service_integrations,
    aws_api_gateway_integration.lambda_service_proxy_integrations,
    aws_api_gateway_integration.global_proxy_integration,
    aws_api_gateway_integration.root_integration,
    aws_api_gateway_integration.customer_owners_integration,
    aws_api_gateway_integration.customer_owners_id_integration,
    aws_api_gateway_integration.customer_owners_id_get_integration,
    aws_api_gateway_integration.customer_owners_pets_integration,
    aws_api_gateway_integration.customer_owners_pets_id_integration,
    # CORS 관련 의존성 추가
    aws_api_gateway_method.cors_options,
    aws_api_gateway_integration.cors_integrations,
    aws_api_gateway_method_response.cors_method_responses,
    aws_api_gateway_integration_response.cors_integration_responses,
  ]

  rest_api_id = aws_api_gateway_rest_api.petclinic.id

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
      # CORS 설정 추가 (강제 재배포 트리거)
      cors_update = timestamp()
    }))
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

  # X-Ray 추적 활성화
  xray_tracing_enabled = var.enable_xray_tracing
}

# API Gateway 메서드 설정 (실행 로깅)
resource "aws_api_gateway_method_settings" "petclinic" {
  rest_api_id = aws_api_gateway_rest_api.petclinic.id
  stage_name  = aws_api_gateway_stage.petclinic.stage_name
  method_path = "*/*"

  settings {
    logging_level      = "OFF"
    data_trace_enabled = false
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
  name              = "/aws/apigateway/${var.name_prefix}-api"
  retention_in_days = var.log_retention_days

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-api-gateway-logs"
    Type = "logging"
  })
}

# CloudWatch 로그 그룹 (API Gateway 실행 로그용)
resource "aws_cloudwatch_log_group" "api_gateway_execution" {
  name              = "/aws/apigateway/${var.name_prefix}-api-execution"
  retention_in_days = var.log_retention_days

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-api-gateway-execution-logs"
    Type = "logging"
  })
}

# ==========================================
# Lambda 권한 설정
# ==========================================

# Lambda 함수 호출 권한 (API Gateway에서 Lambda 호출 허용)
resource "aws_lambda_permission" "api_gateway_lambda" {
  count = var.enable_lambda_integration ? 1 : 0

  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = element(split("/", var.lambda_function_invoke_arn), 3) # ARN에서 함수 이름 추출
  principal     = "apigateway.amazonaws.com"

  # API Gateway의 모든 경로에서 Lambda 호출 허용
  source_arn = "${aws_api_gateway_rest_api.petclinic.execution_arn}/*/*"

  depends_on = [
    aws_api_gateway_rest_api.petclinic,
    aws_api_gateway_deployment.petclinic
  ]
}

