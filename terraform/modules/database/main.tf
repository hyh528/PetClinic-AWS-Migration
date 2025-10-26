# =============================================================================
# Database Module - Aurora MySQL 클러스터
# =============================================================================
# 목적: 재사용 가능한 Aurora MySQL 클러스터 모듈

# 현재 AWS 리전 정보
data "aws_region" "current" {}

# 로컬 변수
locals {
  # 환경별 설정
  is_production = contains(["prd", "prod", "production"], var.environment)

  # 모니터링 설정
  enhanced_monitoring_enabled = var.monitoring_interval > 0

  # 공통 태그
  common_tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "terraform"
    Module      = "database"
    Engine      = "aurora-mysql"
  })
}

# =============================================================================
# DB 서브넷 그룹
# =============================================================================

resource "aws_db_subnet_group" "this" {
  name       = "${var.name_prefix}-aurora-subnet-group"
  subnet_ids = var.private_db_subnet_ids

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-aurora-subnet-group"
    Type = "db-subnet-group"
  })
}

# =============================================================================
# Aurora MySQL 클러스터
# =============================================================================

resource "aws_rds_cluster" "this" {
  cluster_identifier = "${var.name_prefix}-aurora-cluster"

  # 엔진 설정
  engine         = "aurora-mysql"
  engine_version = var.engine_version

  # 데이터베이스 설정
  database_name   = var.db_name
  master_username = var.db_username
  port            = var.db_port

  # AWS 관리형 비밀번호
  manage_master_user_password = var.manage_master_user_password

  # 네트워크 설정
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = var.vpc_security_group_ids

  # 백업 설정
  backup_retention_period      = var.backup_retention_period
  preferred_backup_window      = var.backup_window
  preferred_maintenance_window = var.maintenance_window

  # 삭제 보호 설정
  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.name_prefix}-aurora-final-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  # Aurora Serverless v2 설정
  serverlessv2_scaling_configuration {
    min_capacity = local.is_production ? 1.0 : 0.5
    max_capacity = local.is_production ? 4.0 : 1.0
  }

  # RDS Data API는 Serverless v2에서 enable_http_endpoint 속성으로 활성화되지 않음
  # 별도로 AWS CLI enable-http-endpoint 호출 필요

  # 암호화 설정
  storage_encrypted = var.storage_encrypted
  kms_key_id        = var.kms_key_id

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-aurora-cluster"
    Type = "aurora-cluster"
  })
}

# =============================================================================
# RDS Data API 활성화 (Aurora MySQL 3.08.0 + Serverless v2)
# =============================================================================
# Aurora Serverless v2에서는 enable_http_endpoint 속성이 동작하지 않으므로
# 클러스터 생성 후 별도의 AWS CLI 호출로 활성화

resource "null_resource" "enable_data_api" {
  triggers = {
    cluster_arn = aws_rds_cluster.this.arn
    engine_version = aws_rds_cluster.this.engine_version
  }

  provisioner "local-exec" {
    command = "aws rds enable-http-endpoint --resource-arn ${aws_rds_cluster.this.arn} --region ${data.aws_region.current.name}"
  }

  depends_on = [
    aws_rds_cluster.this,
    aws_rds_cluster_instance.writer,
    aws_rds_cluster_instance.reader
  ]
}

# =============================================================================
# Aurora 클러스터 인스턴스들
# =============================================================================

# Writer 인스턴스
resource "aws_rds_cluster_instance" "writer" {
  identifier         = "${var.name_prefix}-aurora-writer"
  cluster_identifier = aws_rds_cluster.this.id
  instance_class     = var.instance_class
  engine             = aws_rds_cluster.this.engine
  engine_version     = aws_rds_cluster.this.engine_version

  # 모니터링 설정
  monitoring_interval = var.monitoring_interval
  monitoring_role_arn = local.enhanced_monitoring_enabled ? aws_iam_role.enhanced_monitoring[0].arn : null

  # Performance Insights 설정
  performance_insights_enabled          = var.performance_insights_enabled
  performance_insights_retention_period = var.performance_insights_enabled ? var.performance_insights_retention_period : null

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-aurora-writer"
    Type = "aurora-writer"
    Role = "primary"
  })
}

# Reader 인스턴스
resource "aws_rds_cluster_instance" "reader" {
  identifier         = "${var.name_prefix}-aurora-reader"
  cluster_identifier = aws_rds_cluster.this.id
  instance_class     = var.instance_class
  engine             = aws_rds_cluster.this.engine
  engine_version     = aws_rds_cluster.this.engine_version

  # 모니터링 설정
  monitoring_interval = var.monitoring_interval
  monitoring_role_arn = local.enhanced_monitoring_enabled ? aws_iam_role.enhanced_monitoring[0].arn : null

  # Performance Insights 설정
  performance_insights_enabled          = var.performance_insights_enabled
  performance_insights_retention_period = var.performance_insights_enabled ? var.performance_insights_retention_period : null

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-aurora-reader"
    Type = "aurora-reader"
    Role = "replica"
  })
}

# =============================================================================
# Enhanced Monitoring IAM 역할 (조건부)
# =============================================================================

resource "aws_iam_role" "enhanced_monitoring" {
  count = local.enhanced_monitoring_enabled ? 1 : 0

  name = "${var.name_prefix}-aurora-enhanced-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-aurora-enhanced-monitoring-role"
    Type = "iam-role"
  })
}

resource "aws_iam_role_policy_attachment" "enhanced_monitoring" {
  count = local.enhanced_monitoring_enabled ? 1 : 0

  role       = aws_iam_role.enhanced_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}
