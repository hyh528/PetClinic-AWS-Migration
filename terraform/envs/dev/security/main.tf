# terraform/envs/dev/security/main.tf

# =================================================
# 1) IAM 사용자 및 그룹 관리
# =================================================
# IAM 모듈 호출
module "iam" {
  source = "../../../modules/iam"

  project_name = "petclinic"
  db_secret_arn = data.terraform_remote_state.database.outputs.db_master_user_secret_arn
  db_secret_kms_key_arn = data.terraform_remote_state.database.outputs.db_kms_key_arn
  team_members = var.team_members # aws sns를 통한 알람 설정용 (ms_teams)
}

# API Gateway CloudWatch Logs 계정 설정
resource "aws_api_gateway_account" "this" {
  cloudwatch_role_arn = module.iam.api_gateway_cloudwatch_logs_role_arn
}
# =================================================
# 2) 보안 그룹 (Security Groups)
# =================================================

# --- 데이터 소스: 다른 레이어의 상태 파일 읽어오기 ---
data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket         = var.tfstate_bucket_name
    key            = "dev/yeonghyeon/network/terraform.tfstate"
    region         = var.aws_region
    dynamodb_table = var.tf_lock_table_name
    encrypt        = var.encrypt_state
    profile        = var.network_state_profile
  }
}

data "terraform_remote_state" "database" {
  backend = "s3"
  config = {
    bucket         = var.tfstate_bucket_name
    key            = "dev/junje/database/terraform.tfstate" # 중요: 담당자 이름(junje)을 실제 담당자로 변경하세요.
    region         = var.aws_region
    dynamodb_table = var.tf_lock_table_name
    encrypt        = var.encrypt_state
    profile        = var.database_state_profile # dev.tfvars에 정의된 프로필
  }
}


# --- 보안 그룹 생성 전략 ---
# (설명 주석 생략)

# --- 2-1. ALB 보안 그룹 (Public Subnet 계층) ---
module "sg_alb" {
  source = "../../../modules/sg"

  sg_type     = "alb"
  name_prefix = "petclinic-dev"
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id
  vpc_cidr    = data.terraform_remote_state.network.outputs.vpc_cidr

  tags = {
    Service = "ALB"
  }
}


# --- 2-2. App 보안 그룹 (Private App Subnet 계층) ---
module "sg_app" {
  source = "../../../modules/sg"

  sg_type                      = "app"
  name_prefix                  = "petclinic-dev"
  vpc_id                       = data.terraform_remote_state.network.outputs.vpc_id
  vpc_cidr                     = data.terraform_remote_state.network.outputs.vpc_cidr
  alb_source_security_group_id = module.sg_alb.security_group_id

  tags = {
    Service = "Application"
  }
}


# --- 2-3. DB 보안 그룹 (Private DB Subnet 계층) ---
module "sg_db" {
  source = "../../../modules/sg"

  sg_type                      = "db"
  name_prefix                  = "petclinic-dev"
  vpc_id                       = data.terraform_remote_state.network.outputs.vpc_id
  vpc_cidr                     = data.terraform_remote_state.network.outputs.vpc_cidr
  app_source_security_group_id = module.sg_app.security_group_id

  tags = {
    Service = "Database"
  }
}

# =================================================
# 3) 네트워크 ACL (Network Access Control List)
# =================================================

# VPC Flow Logs를 위한 IAM 역할 및 정책
resource "aws_iam_role" "vpc_flow_logs_role" {
  name = "vpc-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "vpc_flow_logs_policy" {
  role       = aws_iam_role.vpc_flow_logs_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess" # 최소 권한 원칙에 따라 세분화 필요
}

# VPC Flow Logs를 위한 CloudWatch Logs 그룹
resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name = "/aws/vpc-flow-logs/petclinic"
}

# VPC Flow Logs for NACL monitoring
resource "aws_flow_log" "nacl_monitoring" {
  iam_role_arn         = aws_iam_role.vpc_flow_logs_role.arn
  log_destination      = aws_cloudwatch_log_group.vpc_flow_logs.arn
  log_destination_type = "cloud-watch-logs"
  traffic_type         = "ALL"
  vpc_id               = data.terraform_remote_state.network.outputs.vpc_id

  tags = {
    Name        = "petclinic-dev-nacl-flow-logs"
    Purpose     = "NACL traffic monitoring and security analysis"
    Environment = var.environment
  }
}

# CloudWatch 메트릭 필터 (보안 이벤트 감지)
resource "aws_cloudwatch_log_metric_filter" "nacl_denies" {
  name           = "petclinic-dev-nacl-denies"
  log_group_name = aws_cloudwatch_log_group.vpc_flow_logs.name
  pattern        = "[version, account, eni, source, destination, srcport, destport, protocol, packets, bytes, windowstart, windowend, action=\"REJECT\", flowlogstatus]"

  metric_transformation {
    name      = "NACLDeniedConnections"
    namespace = "Security/NACL"
    value     = "1"
  }
}

# CloudWatch 알람 (보안 이벤트 알림)
resource "aws_cloudwatch_metric_alarm" "nacl_security_alert" {
  alarm_name          = "petclinic-dev-nacl-security-alert"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "NACLDeniedConnections"
  namespace           = "Security/NACL"
  period              = "300"
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "This metric monitors NACL denied connections for security threats"
  alarm_actions       = [module.cloudwatch_dashboard.sns_topic_arn]

  tags = {
    Name        = "petclinic-dev-nacl-security-alert"
    Environment = var.environment
  }
}

# --- 3-1. Public Subnet NACL ---
module "nacl_public" {
  source = "../../../modules/nacl"

  name_prefix = "public"
  environment = var.environment
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id
  vpc_cidr    = data.terraform_remote_state.network.outputs.vpc_cidr
  nacl_type   = "public"
  subnet_ids  = values(data.terraform_remote_state.network.outputs.public_subnet_ids)
}

# --- 3-2. Private App Subnet NACL ---
module "nacl_private_app" {
  source = "../../../modules/nacl"

  name_prefix = "private-app"
  environment = var.environment
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id
  vpc_cidr    = data.terraform_remote_state.network.outputs.vpc_cidr
  nacl_type   = "private-app"
  subnet_ids  = values(data.terraform_remote_state.network.outputs.private_app_subnet_ids)
}

# --- 3-3. Private DB Subnet NACL ---
module "nacl_private_db" {
  source = "../../../modules/nacl"

  name_prefix = "private-db"
  environment = var.environment
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id
  vpc_cidr    = data.terraform_remote_state.network.outputs.vpc_cidr
  nacl_type   = "private-db"
  subnet_ids  = values(data.terraform_remote_state.network.outputs.private_db_subnet_ids)
}

# =================================================
# 4) VPC 엔드포인트 (VPC Endpoints)
# =================================================

# --- 4-1. VPC Endpoint 보안 그룹 ---
data "aws_region" "current" {}

module "sg_vpce" {
  source = "../../../modules/sg"

  sg_type     = "vpce"
  name_prefix = var.name_prefix
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id
  vpc_cidr    = data.terraform_remote_state.network.outputs.vpc_cidr

  tags = {
    Service = "VPCE"
  }
}

# --- 4-2. VPC Endpoints 생성 ---
module "endpoint" {
  source = "../../../modules/endpoint"

  vpc_id                    = data.terraform_remote_state.network.outputs.vpc_id
  private_subnet_ids        = values(data.terraform_remote_state.network.outputs.private_app_subnet_ids)
  private_route_table_ids   = values(data.terraform_remote_state.network.outputs.private_app_route_table_ids)
  vpc_endpoint_sg_id        = module.sg_vpce.security_group_id
  aws_region                = data.aws_region.current.id
  project_name              = var.name_prefix
  environment               = var.environment
}

# =================================================
# 5) Cognito (사용자 인증 및 권한 부여)
# =================================================

# --- 5-1. 사용자 인증 및 권한 부여 ---
module "cognito" {
  source = "../../../modules/cognito"

  project_name          = var.name_prefix
  environment           = var.environment
  cognito_callback_urls = ["http://localhost:8080/login"]
  cognito_logout_urls   = ["http://localhost:8080/logout"]
}

# =================================================
# 6) CloudTrail (감사 및 로깅)
# =================================================

# CloudTrail을 위한 CloudWatch Logs 그룹
resource "aws_cloudwatch_log_group" "cloudtrail" {
  name = "petclinic-trail"
}

# CloudTrail이 CloudWatch Logs에 쓰기 위한 IAM 역할
resource "aws_iam_role" "cloudtrail_to_cloudwatch" {
  name = "cloudtrail-to-cloudwatch-role-v2"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
      }
    ]
  })
}

# CloudTrail이 CloudWatch Logs에 쓰기 위한 IAM 정책
resource "aws_iam_role_policy" "cloudtrail_to_cloudwatch" {
  name = "cloudtrail-to-cloudwatch-policy-v2"
  role = aws_iam_role.cloudtrail_to_cloudwatch.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Effect   = "Allow",
        Resource = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
      }
    ]
  })
}

# AWS 계정 ID를 가져오기 위한 데이터 소스
data "aws_caller_identity" "current" {}

module "cloudtrail" {
  source = "../../../modules/cloudtrail"

  trail_name     = "petclinic-trail"
  s3_bucket_name = "petclinic-cloudtrail-logs-${data.aws_caller_identity.current.account_id}"

  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
  cloud_watch_logs_role_arn  = aws_iam_role.cloudtrail_to_cloudwatch.arn

  depends_on = [aws_iam_role_policy.cloudtrail_to_cloudwatch]

  tags = {
    Project     = var.name_prefix
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# =================================================
# 7) ECS CloudWatch Logs (누락된 로그 그룹 생성)
# =================================================

resource "aws_cloudwatch_log_group" "ecs_petclinic_cluster" {
  name              = "/ecs/petclinic/petclinic-cluster"
  retention_in_days = 30 # 적절한 보존 기간으로 설정
  tags = {
    Name        = "petclinic-ecs-cluster-logs"
    Environment = var.environment
    Project     = var.name_prefix
  }
}

# =================================================
# 7) X-Ray (분산 추적)
# =================================================

# X-Ray 암호화를 위한 AWS 관리형 KMS 키의 ARN을 조회합니다.
data "aws_kms_alias" "xray" {
  name = "alias/aws/xray"
}

resource "aws_xray_encryption_config" "this" {
  type = "KMS"
  key_id = data.aws_kms_alias.xray.target_key_arn
}
 # =================================================                  
 # 8) IAM Policies (중앙 관리)                                        
 # =================================================                  
                                                                      
 # --- 8-1. ECS SSM Parameter Store 접근 정책 ---                     
 resource "aws_iam_policy" "ecs_ssm_access_policy" {                  
   name        = "petclinic-ecs-ssm-access-policy"                    
   description = "Allows ECS tasks to access specific SSM parameters" 
   policy = jsonencode({                                              
     Version = "2012-10-17",                                          
     Statement = [
       {
         Effect = "Allow",
         Action = [
           "ssm:GetParametersByPath",
           "ssm:GetParameters",
           "ssm:GetParameter"
         ],
         Resource = "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/petclinic/*"  
       }
     ]
   })                                                                 
 }                      

# =================================================
# 9) CloudWatch Dashboard (모니터링)
# =================================================

# --- 데이터 소스: Application 레이어 상태 파일 ---
data "terraform_remote_state" "application" {
  backend = "s3"
  config = {
    bucket         = var.tfstate_bucket_name
    key            = "dev/seokgyeom/application/terraform.tfstate"
    region         = var.aws_region
    dynamodb_table = var.tf_lock_table_name
    encrypt        = var.encrypt_state
    profile        = var.database_state_profile # Assuming same profile as database
  }
}

# --- CloudWatch 대시보드 모듈 호출 ---
module "cloudwatch_dashboard" {
  source = "../../../modules/cloudwatch"

  project_name = var.name_prefix
  environment  = var.environment
  aws_region   = data.aws_region.current.name

  services = {
    for k, v in data.terraform_remote_state.application.outputs.ecs_service_names : k => {
      ecs_cluster_name           = data.terraform_remote_state.application.outputs.ecs_cluster_name
      ecs_service_name           = v
      alb_arn_suffix             = data.terraform_remote_state.application.outputs.alb_arn_suffix
      alb_target_group_id        = split(":", data.terraform_remote_state.application.outputs.alb_target_group_arns[k])[5]
    } if contains(["vets-service", "visits-service", "customers-service"], k)
  }

  tags = {
    Service = "Monitoring"
  }

  db_cluster_identifier = data.terraform_remote_state.database.outputs.db_cluster_resource_id
  cpu_threshold         = 80
  memory_threshold      = 80

  # lambda_function_arn  = module.lambda_teams_notifier.lambda_function_arn
  # lambda_function_name = module.lambda_teams_notifier.lambda_function_name
}

# =================================================
# 10) Lambda Teams Notifier (대안)
# =================================================
#
# module "lambda_teams_notifier" {
#   source = "../../../modules/lambda-teams-notifier"
#
#   project_name        = var.project_name
#   environment         = var.environment
#   lambda_iam_role_arn = module.iam.lambda_teams_notifier_role_arn
#   teams_webhook_url   = var.teams_webhook_url # 이 변수는 dev.tfvars에 추가해야 합니다.
#   tags                = { Service = "Notification" }
# }

# =================================================
# 11) Security Group Rules (순환 종속성 해결)
# =================================================

resource "aws_security_group_rule" "app_from_alb" {
  for_each = toset(["8080", "8081", "8082", "8083", "9090"])

  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = tonumber(each.value)
  to_port                  = tonumber(each.value)
  source_security_group_id = module.sg_alb.security_group_id
  security_group_id        = module.sg_app.security_group_id
  description              = "Allow TCP on port ${each.value} from ALB SG"
}

# resource "aws_security_group_rule" "alb_from_app" {
#   for_each = toset(["8080", "8081", "8082", "8083", "9090"])

#   type                     = "ingress"
#   protocol                 = "tcp"
#   from_port                = tonumber(each.value)
#   to_port                  = tonumber(each.value)
#   source_security_group_id = module.sg_app.security_group_id
#   security_group_id        = module.sg_alb.security_group_id
#   description              = "Allow TCP on port ${each.value} from App SG"
# }