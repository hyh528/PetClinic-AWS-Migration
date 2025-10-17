# 08. API Gateway

## AWS 콘솔 확인 방법

1. **API Gateway > APIs**:
    - `petclinic-dev-api`
2. **API Gateway > Stages**:
    - `dev` 스테이지
3. **API Gateway > Resources**:
    - `/customers`
    - `/vets`
    - `/visits`
    - `/admin`
    - `/genai`
4. **API Gateway > Usage Plans** (선택사항):
    - `petclinic-dev-usage-plan`
5. **CloudWatch > Log Groups**:
    - `API-Gateway-Execution-Logs_{rest-api-id}/dev`

## AWS CLI로 확인 방법

```bash
# API Gateway REST API 확인
aws apigateway get-rest-apis --region ap-northeast-2 --query "items[?name=='petclinic-dev-api'].[name,id,description,createdDate]" --output table

# API Gateway 스테이지 확인
REST_API_ID=$(aws apigateway get-rest-apis --region ap-northeast-2 --query "items[?name=='petclinic-dev-api'].id" --output text)
aws apigateway get-stages --rest-api-id $REST_API_ID --region ap-northeast-2 --query "item[*].[stageName,description,lastUpdatedDate]" --output table

# API Gateway 리소스 확인
aws apigateway get-resources --rest-api-id $REST_API_ID --region ap-northeast-2 --query "items[*].[path,pathPart,resourceMethods]" --output table

# API Gateway 배포 확인
aws apigateway get-deployments --rest-api-id $REST_API_ID --region ap-northeast-2 --query "items[*].[id,description,createdDate]" --output table

# API Gateway 사용량 계획 확인
aws apigateway get-usage-plans --region ap-northeast-2 --query "items[?name=='petclinic-dev-usage-plan'].[name,id,description,throttle,quota]" --output table

# CloudWatch 로그 그룹 확인
aws logs describe-log-groups --log-group-name-prefix "API-Gateway-Execution-Logs_" --region ap-northeast-2 --query "logGroups[*].[logGroupName,retentionInDays]" --output table

# 상태 파일 확인
cd terraform/layers/08-api-gateway && terraform state list

data.terraform_remote_state.application
data.terraform_remote_state.lambda_genai
module.api_gateway.aws_api_gateway_account.api_gateway_account
module.api_gateway.aws_api_gateway_base_path_mapping.api_gateway_domain_mapping
module.api_gateway.aws_api_gateway_deployment.api_gateway_deployment
module.api_gateway.aws_api_gateway_domain_name.api_gateway_custom_domain
module.api_gateway.aws_api_gateway_integration.alb_integration
module.api_gateway.aws_api_gateway_integration.lambda_integration
module.api_gateway.aws_api_gateway_integration_response.alb_integration_response
module.api_gateway.aws_api_gateway_integration_response.lambda_integration_response
module.api_gateway.aws_api_gateway_method.alb_method
module.api_gateway.aws_api_gateway_method.lambda_method
module.api_gateway.aws_api_gateway_method_response.alb_method_response
module.api_gateway.aws_api_gateway_method_response.lambda_method_response
module.api_gateway.aws_api_gateway_resource.alb_resource
module.api_gateway.aws_api_gateway_resource.lambda_resource
module.api_gateway.aws_api_gateway_rest_api.api_gateway
module.api_gateway.aws_api_gateway_stage.api_gateway_stage
module.api_gateway.aws_api_gateway_usage_plan.api_gateway_usage_plan
module.api_gateway.aws_cloudwatch_log_group.api_gateway_logs
module.api_gateway.aws_lambda_permission.api_gateway_lambda_permission

# output 확인
cd terraform/layers/08-api-gateway && terraform output

api_domain_name = "api.petclinic.dev"
api_gateway_invoke_url = "https://xxxxxxxxxx.execute-api.ap-northeast-2.amazonaws.com/dev"
rest_api_id = "xxxxxxxxxx"
stage_arn = "arn:aws:apigateway:ap-northeast-2::/restapis/xxxxxxxxxx/stages/dev"
stage_name = "dev"