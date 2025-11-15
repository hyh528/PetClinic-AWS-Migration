# ==========================================
# CORS 설정 (모듈화)
# ==========================================

# CORS OPTIONS 메서드 (동적 생성)
resource "aws_api_gateway_method" "cors_options" {
  for_each = local.cors_resources

  rest_api_id   = aws_api_gateway_rest_api.petclinic.id
  resource_id   = each.value.resource_id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

# CORS 통합 설정 (동적 생성)
resource "aws_api_gateway_integration" "cors_integrations" {
  for_each = local.cors_resources

  rest_api_id = aws_api_gateway_rest_api.petclinic.id
  resource_id = each.value.resource_id
  http_method = aws_api_gateway_method.cors_options[each.key].http_method

  # 모든 리소스에 MOCK 타입 사용 (프록시 리소스에서도 작동)
  type = "MOCK"

  # 수정된 request_templates - 올바른 JSON 형식
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }

  # 패스스루 동작 설정
  passthrough_behavior = "WHEN_NO_MATCH"
}

# CORS 메서드 응답 (동적 생성)
resource "aws_api_gateway_method_response" "cors_method_responses" {
  for_each = local.cors_resources

  rest_api_id = aws_api_gateway_rest_api.petclinic.id
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

  rest_api_id = aws_api_gateway_rest_api.petclinic.id
  resource_id = each.value.resource_id
  http_method = aws_api_gateway_method.cors_options[each.key].http_method
  status_code = aws_api_gateway_method_response.cors_method_responses[each.key].status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token,Accept,Accept-Language,Content-Language'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS,POST,PUT,DELETE,HEAD,PATCH'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  response_templates = {
    "application/json" = "{}"
  }

  depends_on = [aws_api_gateway_integration.cors_integrations]
}