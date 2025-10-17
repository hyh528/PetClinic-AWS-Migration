# 04. Parameter Store

## AWS 콘솔 확인 방법

1. **Systems Manager > Parameter Store**:
    - `/petclinic/dev/config/database/host`
    - `/petclinic/dev/config/database/port`
    - `/petclinic/dev/config/database/name`
    - `/petclinic/dev/config/database/username`
    - `/petclinic/dev/config/spring/profiles/active`
    - `/petclinic/dev/config/server/port`
    - `/petclinic/dev/config/logging/level`

## AWS CLI로 확인 방법

```bash
# Parameter Store 파라미터 확인
aws ssm describe-parameters --parameter-filters "Key=Name,Option=BeginsWith,Values=/petclinic/dev" --region ap-northeast-2 --query "Parameters[*].[Name,Type,LastModifiedDate]" --output table

# 파라미터 값 확인 (예시)
aws ssm get-parameter --name "/petclinic/dev/config/database/host" --region ap-northeast-2 --query "Parameter.Value" --output text

# 모든 파라미터 값 확인
aws ssm get-parameters-by-path --path "/petclinic/dev/config" --region ap-northeast-2 --query "Parameters[*].[Name,Value]" --output table

# 상태 파일 확인
cd terraform/layers/04-parameter-store && terraform state list

data.terraform_remote_state.database
module.parameter_store.aws_ssm_parameter.database_host
module.parameter_store.aws_ssm_parameter.database_name
module.parameter_store.aws_ssm_parameter.database_port
module.parameter_store.aws_ssm_parameter.database_username
module.parameter_store.aws_ssm_parameter.logging_level
module.parameter_store.aws_ssm_parameter.server_port
module.parameter_store.aws_ssm_parameter.spring_profiles_active

# output 확인
cd terraform/layers/04-parameter-store && terraform output

# Parameter Store 레이어는 주로 파라미터 생성을 담당하므로 output이 없을 수 있음
# 필요시 아래 명령어로 확인
aws ssm get-parameters-by-path --path "/petclinic/dev/config" --region ap-northeast-2 --query "Parameters[*].[Name,Value,Type]" --output table