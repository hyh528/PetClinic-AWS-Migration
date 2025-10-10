# ==========================================
# 공통 표준 정의 모듈
# ==========================================
# 클린 코드 원칙: DRY (Don't Repeat Yourself)
# 모든 리소스에서 일관된 태그 및 명명 규칙 적용

# ==========================================
# 명명 규칙 표준화
# ==========================================
locals {
  # 기본 명명 규칙: {project}-{environment}-{component}-{resource_type}
  naming_convention = {
    # 프로젝트 식별자
    project = var.project_name

    # 환경 식별자
    environment = var.environment

    # 명명 규칙 함수들
    resource_name = "${var.project_name}-${var.environment}"

    # 컴포넌트별 명명 규칙
    api_gateway    = "${var.project_name}-${var.environment}-api"
    lambda         = "${var.project_name}-${var.environment}-lambda"
    ecs_cluster    = "${var.project_name}-${var.environment}-cluster"
    ecs_service    = "${var.project_name}-${var.environment}-service"
    alb            = "${var.project_name}-${var.environment}-alb"
    database       = "${var.project_name}-${var.environment}-db"
    vpc            = "${var.project_name}-${var.environment}-vpc"
    security_group = "${var.project_name}-${var.environment}-sg"
    iam_role       = "${var.project_name}-${var.environment}-role"
    s3_bucket      = "${var.project_name}-${var.environment}-${random_id.bucket_suffix.hex}"
    cloudwatch     = "${var.project_name}-${var.environment}-cw"
    parameter      = "/${var.project_name}/${var.environment}"
  }
}

# S3 버킷 이름 고유성을 위한 랜덤 ID
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# ==========================================
# 태그 표준화
# ==========================================
locals {
  # 필수 태그 (모든 리소스에 적용)
  mandatory_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    CreatedBy   = "team-petclinic"
    CreatedAt   = formatdate("YYYY-MM-DD", timestamp())
  }

  # 비용 추적 태그
  cost_tags = {
    CostCenter  = var.cost_center
    Owner       = var.owner
    BillingCode = "${var.project_name}-${var.environment}"
  }

  # 운영 태그
  operational_tags = {
    Backup     = var.backup_required ? "required" : "not-required"
    Monitoring = var.monitoring_enabled ? "enabled" : "disabled"
    Compliance = var.compliance_level
  }

  # 기술 태그
  technical_tags = {
    TerraformModule = var.terraform_module
    Layer           = var.layer
    Component       = var.component
  }

  # 통합 태그 (모든 태그 결합)
  common_tags = merge(
    local.mandatory_tags,
    local.cost_tags,
    local.operational_tags,
    local.technical_tags,
    var.additional_tags
  )
}

# ==========================================
# 보안 표준
# ==========================================
locals {
  # 보안 그룹 명명 규칙
  security_group_names = {
    alb          = "${local.naming_convention.security_group}-alb"
    ecs          = "${local.naming_convention.security_group}-ecs"
    rds          = "${local.naming_convention.security_group}-rds"
    lambda       = "${local.naming_convention.security_group}-lambda"
    vpc_endpoint = "${local.naming_convention.security_group}-vpce"
  }

  # IAM 역할 명명 규칙
  iam_role_names = {
    ecs_task_execution = "${local.naming_convention.iam_role}-ecs-task-execution"
    ecs_task           = "${local.naming_convention.iam_role}-ecs-task"
    lambda_execution   = "${local.naming_convention.iam_role}-lambda-execution"
    cloudtrail         = "${local.naming_convention.iam_role}-cloudtrail"
  }
}

# ==========================================
# 네트워크 표준
# ==========================================
locals {
  # 서브넷 명명 규칙
  subnet_names = {
    public_a      = "${local.naming_convention.resource_name}-public-a"
    public_c      = "${local.naming_convention.resource_name}-public-c"
    private_app_a = "${local.naming_convention.resource_name}-private-app-a"
    private_app_c = "${local.naming_convention.resource_name}-private-app-c"
    private_db_a  = "${local.naming_convention.resource_name}-private-db-a"
    private_db_c  = "${local.naming_convention.resource_name}-private-db-c"
  }

  # 라우트 테이블 명명 규칙
  route_table_names = {
    public      = "${local.naming_convention.resource_name}-rt-public"
    private_app = "${local.naming_convention.resource_name}-rt-private-app"
    private_db  = "${local.naming_convention.resource_name}-rt-private-db"
  }
}

# ==========================================
# 모니터링 표준
# ==========================================
locals {
  # CloudWatch 로그 그룹 명명 규칙
  log_group_names = {
    ecs_app     = "/ecs/${local.naming_convention.resource_name}-app"
    lambda      = "/aws/lambda/${local.naming_convention.lambda}"
    api_gateway = "/aws/apigateway/${local.naming_convention.api_gateway}"
    cloudtrail  = "/aws/cloudtrail/${local.naming_convention.resource_name}-trail"
    xray_daemon = "/ecs/${local.naming_convention.resource_name}-xray-daemon"
  }

  # CloudWatch 대시보드 명명 규칙
  dashboard_names = {
    main = "${local.naming_convention.cloudwatch}-dashboard"
    api  = "${local.naming_convention.cloudwatch}-api-dashboard"
    db   = "${local.naming_convention.cloudwatch}-db-dashboard"
  }
}