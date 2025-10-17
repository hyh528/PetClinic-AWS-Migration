# 10. AWS Native

## AWS 콘솔 확인 방법

1. **API Gateway > APIs** (GenAI 통합):
    - `petclinic-dev-api`의 `/genai` 리소스
2. **Lambda > Functions** (GenAI 통합):
    - `petclinic-dev-genai-function`
3. **WAF > Web ACLs** (선택사항):
    - `petclinic-dev-waf-acl`
4. **CloudWatch > Alarms** (추가 알람):
    - `petclinic-dev-genai-integration-latency`
    - `petclinic-dev-waf-blocked-requests`

## AWS CLI로 확인 방법

```bash
# API Gateway GenAI 통합 확인
REST_API_ID=$(aws apigateway get-rest-apis --region ap-northeast-2 --query "items[?name=='petclinic-dev-api'].id" --output text)
aws apigateway get-integration --rest-api-id $REST_API_ID --resource-id $(aws apigateway get-resources --rest-api-id $REST_API_ID --region ap-northeast-2 --query "items[?pathPart=='genai'].id" --output text) --http-method GET --region ap-northeast-2 --query "[type,integrationHttpMethod,uri]"

# Lambda 함수 GenAI 통합 권한 확인
aws lambda get-policy --function-name petclinic-dev-genai-function --region ap-northeast-2 --query "Policy" | jq '.Statement[] | select(.Principal.Service=="apigateway.amazonaws.com")'

# WAF Web ACL 확인 (활성화된 경우)
aws wafv2 list-web-acls --scope REGIONAL --region ap-northeast-2 --query "WebACLs[?Name=='petclinic-dev-waf-acl'].[Name,Id,ARN]" --output table

# CloudWatch 추가 알람 확인
aws cloudwatch describe-alarms --alarm-name-prefix "petclinic-dev-genai" --region ap-northeast-2 --query "MetricAlarms[*].[AlarmName,StateValue,MetricName]" --output table

# 상태 파일 확인
cd terraform/layers/10-aws-native && terraform state list

data.terraform_remote_state.api_gateway
data.terraform_remote_state.lambda_genai
module.aws_native_integration.aws_api_gateway_integration.genai_integration
module.aws_native_integration.aws_api_gateway_integration_response.genai_integration_response
module.aws_native_integration.aws_api_gateway_method.genai_method
module.aws_native_integration.aws_api_gateway_method_response.genai_method_response
module.aws_native_integration.aws_api_gateway_resource.genai_resource
module.aws_native_integration.aws_cloudwatch_metric_alarm.genai_integration_latency
module.aws_native_integration.aws_lambda_permission.genai_api_gateway_permission
module.aws_native_integration.aws_wafv2_web_acl.waf_acl
module.aws_native_integration.aws_wafv2_web_acl_association.api_gateway_waf
module.aws_native_integration.aws_wafv2_web_acl_association.cloudfront_waf

# output 확인
cd terraform/layers/10-aws-native && terraform output

api_gateway_name = "petclinic-dev-api"
lambda_function_name = "petclinic-dev-genai-function"
waf_acl_arn = "arn:aws:wafv2:ap-northeast-2:<ACCOUNT_ID>:regional/webacl/petclinic-dev-waf-acl/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"