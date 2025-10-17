# 07. Application

## AWS 콘솔 확인 방법

1. **EC2 > Load Balancers**:
    - `petclinic-dev-alb`
2. **EC2 > Target Groups**:
    - `petclinic-dev-customers`
    - `petclinic-dev-vets`
    - `petclinic-dev-visits`
    - `petclinic-dev-admin`
3. **ECS > Clusters**:
    - `petclinic-dev-cluster`
4. **ECS > Services**:
    - `petclinic-dev-customers`
    - `petclinic-dev-vets`
    - `petclinic-dev-visits`
    - `petclinic-dev-admin`
5. **ECS > Task Definitions**:
    - `petclinic-dev-customers`
    - `petclinic-dev-vets`
    - `petclinic-dev-visits`
    - `petclinic-dev-admin`
6. **ECR > Repositories**:
    - `petclinic-dev-customers`
    - `petclinic-dev-vets`
    - `petclinic-dev-visits`
    - `petclinic-dev-admin`
7. **CloudWatch > Log Groups**:
    - `/ecs/petclinic-dev-customers`
    - `/ecs/petclinic-dev-vets`
    - `/ecs/petclinic-dev-visits`
    - `/ecs/petclinic-dev-admin`

## AWS CLI로 확인 방법

```bash
# ALB 확인
aws elbv2 describe-load-balancers --names petclinic-dev-alb --region ap-northeast-2 --query "LoadBalancers[*].[LoadBalancerName,DNSName,State.Code,VpcId]" --output table

# 타겟 그룹 확인
aws elbv2 describe-target-groups --names petclinic-dev-customers petclinic-dev-vets petclinic-dev-visits petclinic-dev-admin --region ap-northeast-2 --query "TargetGroups[*].[TargetGroupName,Protocol,Port,HealthCheckPath]" --output table

# ECS 클러스터 확인
aws ecs describe-clusters --clusters petclinic-dev-cluster --region ap-northeast-2 --query "clusters[*].[clusterName,status,runningTasksCount]" --output table

# ECS 서비스 확인
aws ecs describe-services --cluster petclinic-dev-cluster --services petclinic-dev-customers petclinic-dev-vets petclinic-dev-visits petclinic-dev-admin --region ap-northeast-2 --query "services[*].[serviceName,status,runningCount,desiredCount]" --output table

# ECS 태스크 정의 확인
aws ecs describe-task-definition --task-definition petclinic-dev-customers --region ap-northeast-2 --query "taskDefinition.[family,status,cpu,memory,containerDefinitions[0].[name,image,cpu,memory]]"

# ECR 리포지토리 확인
aws ecr describe-repositories --repository-names petclinic-dev-customers petclinic-dev-vets petclinic-dev-visits petclinic-dev-admin --region ap-northeast-2 --query "repositories[*].[repositoryName,repositoryUri]" --output table

# CloudWatch 로그 그룹 확인
aws logs describe-log-groups --log-group-name-prefix "/ecs/petclinic-dev" --region ap-northeast-2 --query "logGroups[*].[logGroupName,retentionInDays]" --output table

# 상태 파일 확인
cd terraform/layers/07-application && terraform state list

module.alb.aws_lb.main
module.alb.aws_lb_listener.http
module.ecr_services["admin"].aws_ecr_repository.repo
module.ecr_services["customers"].aws_ecr_repository.repo
module.ecr_services["vets"].aws_ecr_repository.repo
module.ecr_services["visits"].aws_ecr_repository.repo
aws_appautoscaling_policy.cpu_scaling["admin"]
aws_appautoscaling_policy.cpu_scaling["customers"]
aws_appautoscaling_policy.cpu_scaling["vets"]
aws_appautoscaling_policy.cpu_scaling["visits"]
aws_appautoscaling_target.services["admin"]
aws_appautoscaling_target.services["customers"]
aws_appautoscaling_target.services["vets"]
aws_appautoscaling_target.services["visits"]
aws_cloudwatch_log_group.services["admin"]
aws_cloudwatch_log_group.services["customers"]
aws_cloudwatch_log_group.services["vets"]
aws_cloudwatch_log_group.services["visits"]
aws_ecs_cluster.main
aws_ecs_service.services["admin"]
aws_ecs_service.services["customers"]
aws_ecs_service.services["vets"]
aws_ecs_service.services["visits"]
aws_ecs_task_definition.services["admin"]
aws_ecs_task_definition.services["customers"]
aws_ecs_task_definition.services["vets"]
aws_ecs_task_definition.services["visits"]
aws_lb_target_group.services["admin"]
aws_lb_target_group.services["customers"]
aws_lb_target_group.services["vets"]
aws_lb_target_group.services["visits"]
aws_lb_listener_rule.services["admin"]
aws_lb_listener_rule.services["customers"]
aws_lb_listener_rule.services["vets"]
aws_lb_listener_rule.services["visits"]

# output 확인
cd terraform/layers/07-application && terraform output

alb_dns_name = "petclinic-dev-alb-xxxxxxxxxxxx.ap-northeast-2.elb.amazonaws.com"
alb_security_group_id = "sg-xxxxxxxxxxxxxxxxx"
alb_zone_id = "Z1D633PJN98FT9"
ecr_repository_urls = {
  "admin" = "<ACCOUNT_ID>.dkr.ecr.ap-northeast-2.amazonaws.com/petclinic-dev-admin"
  "customers" = "<ACCOUNT_ID>.dkr.ecr.ap-northeast-2.amazonaws.com/petclinic-dev-customers"
  "vets" = "<ACCOUNT_ID>.dkr.ecr.ap-northeast-2.amazonaws.com/petclinic-dev-vets"
  "visits" = "<ACCOUNT_ID>.dkr.ecr.ap-northeast-2.amazonaws.com/petclinic-dev-visits"
}