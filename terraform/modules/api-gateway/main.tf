# --------------------------------------
# API Gateway REST API 생성
# --------------------------------------
resource "aws_api_gateway_rest_api" "this" {
  name        = "${var.project_name}-${var.environment}-api"
  description = "PetClinic 애플리케이션용 API Gateway"

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

# --------------------------------------
# 라우팅 맵
# --------------------------------------
locals {
  direct_top_level_services = {
    admin = "admin-server"
  }

  api_sub_services = {
    customers = "customers-service"
    vets      = "vets-service"
    visits    = "visits-service"
  }

  api_path_mappings = {
    customers = "/owners"
    vets      = "/vets"
    visits    = ""
  }
}

# --------------------------------------
# 0) 루트 경로(/) -> ALB 루트
# --------------------------------------
resource "aws_api_gateway_method" "root_any" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_rest_api.this.root_resource_id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "root_alb" {
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_rest_api.this.root_resource_id
  http_method             = aws_api_gateway_method.root_any.http_method
  type                    = "HTTP_PROXY"
  integration_http_method = "ANY"
  # [수정됨] for_each가 없으므로 each.value, each.key 제거
  uri                     = "http://${var.alb_dns_name}/"
}

# --------------------------------------
# 1) 최상위 직접 노출 서비스 (예: /admin/{proxy+})
# --------------------------------------
resource "aws_api_gateway_resource" "direct_service_root" {
  for_each    = local.direct_top_level_services
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = each.key
}

# [신규 추가] /admin 루트 경로 처리                                                                  
resource "aws_api_gateway_method" "direct_service_root_any" {                                        
  for_each      = local.direct_top_level_services                                                    
  rest_api_id   = aws_api_gateway_rest_api.this.id                                                   
  resource_id   = aws_api_gateway_resource.direct_service_root[each.key].id                          
  http_method   = "ANY"                                                                              
  authorization = "NONE"                                                                             
}                                                                                                    
                                                                                                     
# [신규 추가] /admin -> /admin-server/ 로 변환                                                       
resource "aws_api_gateway_integration" "direct_service_root_alb" {                                   
  for_each                = local.direct_top_level_services                                          
  rest_api_id             = aws_api_gateway_rest_api.this.id                                         
  resource_id             = aws_api_gateway_resource.direct_service_root[each.key].id                
  http_method             = aws_api_gateway_method.direct_service_root_any[each.key].http_method     
  type                    = "HTTP_PROXY"                                                             
  integration_http_method = "ANY"                                                                    
  uri                     = "http://${var.alb_dns_name}/${each.value}"                              
}                                                                                                                                                                                                   

resource "aws_api_gateway_resource" "direct_service_proxy" {
  for_each    = local.direct_top_level_services
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.direct_service_root[each.key].id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "direct_proxy_any" {
  for_each      = local.direct_top_level_services
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.direct_service_proxy[each.key].id
  http_method   = "ANY"
  authorization = "NONE"
  request_parameters = { "method.request.path.proxy" = true }
}

resource "aws_api_gateway_integration" "direct_proxy_alb" {
  for_each                = local.direct_top_level_services
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.direct_service_proxy[each.key].id
  http_method             = aws_api_gateway_method.direct_proxy_any[each.key].http_method
  type                    = "HTTP_PROXY"
  integration_http_method = "ANY"
  # [수정됨] 불필요한 each.key 제거
  uri                     = "http://${var.alb_dns_name}/${each.value}/{proxy}"
  request_parameters      = { "integration.request.path.proxy" = "method.request.path.proxy" }        
  timeout_milliseconds    = 29000
}

# --------------------------------------ㅇ
# 2) /api 및 하위 서비스
# --------------------------------------
resource "aws_api_gateway_resource" "api_root" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "api"
}

resource "aws_api_gateway_resource" "api_sub_service_root" {
  for_each    = local.api_sub_services
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.api_root.id
  path_part   = each.key
}

# [신규 추가] /api/vets 와 같은 루트 경로 처리
resource "aws_api_gateway_method" "api_sub_service_root_any" {
  for_each      = local.api_sub_services
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.api_sub_service_root[each.key].id
  http_method   = "ANY"
  authorization = "NONE"
}

# [신규 추가] /api/vets -> /vets-service/vets 로 변환
resource "aws_api_gateway_integration" "api_sub_service_root_alb" {
  for_each                = local.api_sub_services
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.api_sub_service_root[each.key].id
  http_method             = aws_api_gateway_method.api_sub_service_root_any[each.key].http_method     
  type                    = "HTTP_PROXY"
  integration_http_method = "ANY"
  # [핵심 로직] /api/vets -> http://.../vets-service/vets
  uri                     = "http://${var.alb_dns_name}/${each.value}${local.api_path_mappings[each.key]}"
  //uri                     = "http://${var.alb_dns_name}/${each.key}"  // 수정본
}

# [기존] /api/vets/{proxy+} 와 같은 하위 경로 처리
resource "aws_api_gateway_resource" "api_sub_service_proxy" {
  for_each    = local.api_sub_services
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.api_sub_service_root[each.key].id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "api_sub_service_proxy_any" {
  for_each      = local.api_sub_services
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.api_sub_service_proxy[each.key].id
  http_method   = "ANY"
  authorization = "NONE"
  request_parameters = { "method.request.path.proxy" = true }
}

# [기존] /api/vets/{proxy+} -> /vets-service/vets/{proxy+} 로 변환
resource "aws_api_gateway_integration" "api_sub_service_proxy_alb" {
  for_each                = local.api_sub_services
  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = aws_api_gateway_resource.api_sub_service_proxy[each.key].id
  http_method             = aws_api_gateway_method.api_sub_service_proxy_any[each.key].http_method
  type                    = "HTTP_PROXY"
  integration_http_method = "ANY"
  # [핵심 로직] /api/vets/1 -> http://.../vets-service/vets/1
  uri                     = "http://${var.alb_dns_name}/${each.value}${local.api_path_mappings[each.key]}/{proxy}"
  //uri                     = "http://${var.alb_dns_name}/${each.key}/{proxy}"        // 수정본
  request_parameters      = { "integration.request.path.proxy" = "method.request.path.proxy" }        
  timeout_milliseconds    = 29000
}

# --------------------------------------
# CORS 지원 (최상위 직접 노출 서비스용)
# --------------------------------------
resource "aws_api_gateway_method" "direct_proxy_options" {
  for_each      = local.direct_top_level_services
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.direct_service_proxy[each.key].id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "direct_proxy_options" {
  for_each    = local.direct_top_level_services
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.direct_service_proxy[each.key].id
  http_method = aws_api_gateway_method.direct_proxy_options[each.key].http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = jsonencode({ statusCode = 200 })
  }
}

resource "aws_api_gateway_method_response" "direct_proxy_options" {
  for_each    = local.direct_top_level_services
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.direct_service_proxy[each.key].id
  http_method = aws_api_gateway_method.direct_proxy_options[each.key].http_method
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

resource "aws_api_gateway_integration_response" "direct_proxy_options" {
  for_each    = local.direct_top_level_services
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.direct_service_proxy[each.key].id
  http_method = aws_api_gateway_method.direct_proxy_options[each.key].http_method
  status_code = aws_api_gateway_method_response.direct_proxy_options[each.key].status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS,POST,PUT,DELETE'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  response_templates = {
    "application/json" = ""
  }
}

# --------------------------------------
# CORS 지원 (/api 하위 서비스용)
# --------------------------------------
resource "aws_api_gateway_method" "api_sub_service_proxy_options" {
  for_each      = local.api_sub_services
  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = aws_api_gateway_resource.api_sub_service_proxy[each.key].id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "api_sub_service_proxy_options" {
  for_each    = local.api_sub_services
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.api_sub_service_proxy[each.key].id
  http_method = aws_api_gateway_method.api_sub_service_proxy_options[each.key].http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = jsonencode({ statusCode = 200 })
  }
}

resource "aws_api_gateway_method_response" "api_sub_service_proxy_options" {
  for_each    = local.api_sub_services
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.api_sub_service_proxy[each.key].id
  http_method = aws_api_gateway_method.api_sub_service_proxy_options[each.key].http_method
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

resource "aws_api_gateway_integration_response" "api_sub_service_proxy_options" {
  for_each    = local.api_sub_services
  rest_api_id = aws_api_gateway_rest_api.this.id
  resource_id = aws_api_gateway_resource.api_sub_service_proxy[each.key].id
  http_method = aws_api_gateway_method.api_sub_service_proxy_options[each.key].http_method
  status_code = aws_api_gateway_method_response.api_sub_service_proxy_options[each.key].status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS,POST,PUT,DELETE'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  response_templates = {
    "application/json" = ""
  }
}

# --------------------------------------
# 배포 & 스테이지
# --------------------------------------
resource "aws_api_gateway_deployment" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  description = "Deployment for ${var.environment} stage"

  triggers = {
    redeployment = sha1(jsonencode([
      # 루트
      aws_api_gateway_method.root_any.id,
      aws_api_gateway_integration.root_alb.id,

      # 최상위 직접 노출 서비스
      values(aws_api_gateway_method.direct_service_root_any)[*].id,         
      values(aws_api_gateway_integration.direct_service_root_alb)[*].id,    
      values(aws_api_gateway_resource.direct_service_proxy)[*].id,
      values(aws_api_gateway_method.direct_proxy_any)[*].id,
      values(aws_api_gateway_integration.direct_proxy_alb)[*].id,

      # /api 및 하위
      aws_api_gateway_resource.api_root.id,
      values(aws_api_gateway_resource.api_sub_service_root)[*].id, # 추가된 부분
      values(aws_api_gateway_method.api_sub_service_root_any)[*].id, # 추가된 부분
      values(aws_api_gateway_integration.api_sub_service_root_alb)[*].id, # 추가된 부분
      values(aws_api_gateway_resource.api_sub_service_proxy)[*].id,
      values(aws_api_gateway_method.api_sub_service_proxy_any)[*].id,
      values(aws_api_gateway_integration.api_sub_service_proxy_alb)[*].id,

      # CORS(직접 노출)
      values(aws_api_gateway_method.direct_proxy_options)[*].id,
      values(aws_api_gateway_integration.direct_proxy_options)[*].id,
      values(aws_api_gateway_method_response.direct_proxy_options)[*].id,
      values(aws_api_gateway_integration_response.direct_proxy_options)[*].id,

      # CORS(/api 하위)
      values(aws_api_gateway_method.api_sub_service_proxy_options)[*].id,
      values(aws_api_gateway_integration.api_sub_service_proxy_options)[*].id,
      values(aws_api_gateway_method_response.api_sub_service_proxy_options)[*].id,
      values(aws_api_gateway_integration_response.api_sub_service_proxy_options)[*].id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "this" {
  rest_api_id   = aws_api_gateway_rest_api.this.id
  deployment_id = aws_api_gateway_deployment.this.id
  stage_name    = var.environment
  description   = "PetClinic ${var.environment} 환경 스테이지"
  xray_tracing_enabled = true

  tags = {
    Name        = "${var.project_name}-${var.environment}-stage"
    Project     = var.project_name
    Environment = var.environment
  }

  # (선택) 액세스 로그 설정을 사용하려면 아래 주석 해제 및 IAM 권한 구성 필요
  # access_log_settings {
  #   destination_arn = aws_cloudwatch_log_group.api_gateway_logs.arn
  #   format          = jsonencode({ requestId = "$context.requestId", ip = "$context.identity.sourceIp", requestTime = "$context.requestTime", httpMethod = "$context.httpMethod", path = "$context.path", status = "$context.status", protocol = "$context.protocol", responseLength = "$context.responseLength", integrationError = "$context.integration.error" }))
  # }
}

# --------------------------------------
# CloudWatch Logs (API Gateway 액세스 로그 보관용)
# --------------------------------------
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