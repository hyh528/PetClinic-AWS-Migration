# 06. Lambda GenAI

## AWS 콘솔 확인 방법

1. **Lambda > Functions**:
    - `petclinic-dev-genai-function`
2. **IAM > Roles**:
    - `petclinic-dev-genai-lambda-role`

## AWS CLI로 확인 방법

```bash
# Lambda 함수 확인
aws lambda list-functions --region ap-northeast-2 --query "Functions[?FunctionName=='petclinic-dev-genai-function'].[FunctionName,Runtime,Handler,LastModified]" --output table

# Lambda 함수 세부 정보 확인
aws lambda get-function --function-name petclinic-dev-genai-function --region ap-northeast-2 --query "Configuration.[FunctionName,Runtime,MemorySize,Timeout,Environment]"

# IAM 역할 확인
aws iam get-role --role-name petclinic-dev-genai-lambda-role --region ap-northeast-2 --query "Role.[RoleName,Arn,CreateDate]"

# Lambda 함수 정책 확인
aws iam list-attached-role-policies --role-name petclinic-dev-genai-lambda-role --region ap-northeast-2 --query "AttachedPolicies[*].[PolicyName,PolicyArn]" --output table

# 상태 파일 확인
cd terraform/layers/06-lambda-genai && terraform state list

module.lambda_genai.aws_iam_role.lambda_execution_role
module.lambda_genai.aws_iam_role_policy_attachment.lambda_basic_execution
module.lambda_genai.aws_iam_role_policy_attachment.lambda_bedrock_access
module.lambda_genai.aws_lambda_function.genai_function

# output 확인
cd terraform/layers/06-lambda-genai && terraform output

lambda_function_arn = "arn:aws:lambda:ap-northeast-2:<ACCOUNT_ID>:function:petclinic-dev-genai-function"
lambda_function_invoke_arn = "arn:aws:apigateway:ap-northeast-2:lambda:path/2015-03-31/functions/arn:aws:lambda:ap-northeast-2:<ACCOUNT_ID>:function:petclinic-dev-genai-function/invocations"
lambda_function_name = "petclinic-dev-genai-function"
lambda_iam_role_arn = "arn:aws:iam::<ACCOUNT_ID>:role/petclinic-dev-genai-lambda-role"