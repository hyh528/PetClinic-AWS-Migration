# 02. Security

## AWS 콘솔 확인 방법

1. **Security Groups** (EC2 > Security Groups):
    - `petclinic-dev-ecs-sg`
    - `petclinic-dev-aurora-sg`
2. **IAM Policies** (IAM > Policies):
    - `petclinic-dev-cloudwatch-logs-access`
    - `petclinic-dev-parameter-store-access`
    - `petclinic-dev-rds-secret-access`

## AWS CLI로 확인 방법

```bash
# 보안 그룹 확인
aws ec2 describe-security-groups --filters "Name=group-name,Values=petclinic-dev-*" --region ap-northeast-2 --query "SecurityGroups[*].[GroupName,GroupId]" --output table

# 정책 확인
aws iam list-policies --scope Local --query "Policies[?PolicyName | contains(@, 'petclinic-dev')].[PolicyName,Arn]" --output table

# 상태 파일 확인
cd terraform/layers/02-security && terraform state list

# output 확인
cd terraform/layers/02-security && terraform output