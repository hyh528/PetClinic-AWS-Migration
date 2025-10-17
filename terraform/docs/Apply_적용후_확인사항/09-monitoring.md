# 09. Monitoring

## AWS 콘솔 확인 방법

1. **CloudWatch > Dashboards**:
    - `petclinic-dev-Dashboard`
2. **CloudWatch > Alarms**:
    - `petclinic-dev-api-gateway-4xx-errors`
    - `petclinic-dev-api-gateway-5xx-errors`
    - `petclinic-dev-lambda-errors`
    - `petclinic-dev-alb-target-response-time`
    - `petclinic-dev-alb-unhealthy-hosts`
    - `petclinic-dev-aurora-cpu-utilization`
    - `petclinic-dev-ecs-cpu-utilization`
3. **CloudTrail > Trails**:
    - `petclinic-dev-audit-trail`
4. **S3 > Buckets** (CloudTrail 로그):
    - `petclinic-dev-cloudtrail-logs`

## AWS CLI로 확인 방법

```bash
# CloudWatch 대시보드 확인
aws cloudwatch list-dashboards --region ap-northeast-2 --query "DashboardEntries[?DashboardName=='petclinic-dev-Dashboard'].[DashboardName,DashboardArn,LastModified]" --output table

# CloudWatch 알람 확인
aws cloudwatch describe-alarms --alarm-name-prefix "petclinic-dev" --region ap-northeast-2 --query "MetricAlarms[*].[AlarmName,StateValue,StateReason,MetricName,Namespace]" --output table

# CloudTrail 트레일 확인
aws cloudtrail describe-trails --trail-name-list petclinic-dev-audit-trail --region ap-northeast-2 --query "trailList[*].[Name,S3BucketName,IsMultiRegionTrail,LogFileValidationEnabled]" --output table

# CloudTrail 트레일 상태 확인
aws cloudtrail get-trail-status --name petclinic-dev-audit-trail --region ap-northeast-2 --query "[IsLogging,LatestDeliveryTime,LatestDeliveryError]"

# S3 버킷 확인 (CloudTrail 로그)
aws s3 ls s3://petclinic-dev-cloudtrail-logs/ --region ap-northeast-2

# CloudWatch 로그 그룹 확인 (API Gateway, ECS 등)
aws logs describe-log-groups --region ap-northeast-2 --query "logGroups[?logGroupName | contains(@, 'petclinic-dev')].[logGroupName,retentionInDays,storedBytes]" --output table

# 상태 파일 확인
cd terraform/layers/09-monitoring && terraform state list

data.terraform_remote_state.application
data.terraform_remote_state.aws_native
data.terraform_remote_state.database
module.cloudtrail.aws_cloudtrail.audit_trail
module.cloudtrail.aws_s3_bucket.cloudtrail_logs
module.cloudtrail.aws_s3_bucket_policy.cloudtrail_logs_policy
module.cloudtrail.aws_s3_bucket_public_access_block.cloudtrail_logs
module.cloudtrail.aws_s3_bucket_versioning.cloudtrail_logs
module.cloudwatch.aws_cloudwatch_dashboard.petclinic_dashboard
module.cloudwatch.aws_cloudwatch_metric_alarm.alb_target_response_time
module.cloudwatch.aws_cloudwatch_metric_alarm.alb_unhealthy_hosts
module.cloudwatch.aws_cloudwatch_metric_alarm.api_gateway_4xx_errors
module.cloudwatch.aws_cloudwatch_metric_alarm.api_gateway_5xx_errors
module.cloudwatch.aws_cloudwatch_metric_alarm.api_gateway_latency
module.cloudwatch.aws_cloudwatch_metric_alarm.aurora_cpu_utilization
module.cloudwatch.aws_cloudwatch_metric_alarm.ecs_cpu_utilization
module.cloudwatch.aws_cloudwatch_metric_alarm.lambda_errors
module.cloudwatch.aws_cloudwatch_metric_alarm.lambda_throttles

# output 확인
cd terraform/layers/09-monitoring && terraform output

# Monitoring 레이어는 주로 리소스 생성을 담당하므로 output이 없을 수 있음
# 필요시 CloudWatch 콘솔에서 직접 확인