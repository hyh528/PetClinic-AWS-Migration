# 공통 표준 정의 모듈 메인 파일
# 이 모듈은 프로젝트 전체에서 사용하는 공통 표준과 규칙을 정의합니다.
# 클린 코드 원칙: DRY (Don't Repeat Yourself) - 중복 제거
# 클린 아키텍처 원칙: 의존성 역전 - 공통 규칙을 중앙화

# ==========================================
# 데이터 소스 (현재 AWS 환경 정보)
# ==========================================

# 현재 AWS 계정 정보
data "aws_caller_identity" "current" {}

# 현재 AWS 리전 정보
data "aws_region" "current" {}

# 현재 가용 영역 정보
data "aws_availability_zones" "available" {
  state = "available"
}

# ==========================================
# 공통 리소스 (프로젝트 전체에서 사용)
# ==========================================

# KMS 키 (공통 암호화용)
resource "aws_kms_key" "common" {
  description             = "${var.project_name} ${var.environment} 공통 암호화 키"
  deletion_window_in_days = var.kms_deletion_window
  enable_key_rotation     = true

  tags = merge(local.common_tags, {
    Name      = "${local.naming_convention.resource_name}-kms-key"
    Purpose   = "Common encryption key"
    Component = "security"
  })
}

# KMS 키 별칭
resource "aws_kms_alias" "common" {
  name          = "alias/${local.naming_convention.resource_name}-common"
  target_key_id = aws_kms_key.common.key_id
}

# ==========================================
# 공통 S3 버킷 (로그, 백업 등)
# ==========================================

# 공통 로그 버킷
resource "aws_s3_bucket" "logs" {
  bucket = "${local.naming_convention.s3_bucket}-logs"

  tags = merge(local.common_tags, {
    Name      = "${local.naming_convention.s3_bucket}-logs"
    Purpose   = "Centralized logging storage"
    Component = "logging"
  })
}

# 로그 버킷 버전 관리
resource "aws_s3_bucket_versioning" "logs" {
  bucket = aws_s3_bucket.logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

# 로그 버킷 암호화
resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.common.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

# 로그 버킷 퍼블릭 액세스 차단
resource "aws_s3_bucket_public_access_block" "logs" {
  bucket = aws_s3_bucket.logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 로그 버킷 라이프사이클 정책
resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id     = "log_lifecycle"
    status = "Enabled"

    # 30일 후 IA로 전환
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    # 90일 후 Glacier로 전환
    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    # 365일 후 삭제
    expiration {
      days = 365
    }

    # 불완전한 멀티파트 업로드 정리
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# ==========================================
# 공통 CloudWatch 로그 그룹
# ==========================================

# 공통 애플리케이션 로그 그룹
resource "aws_cloudwatch_log_group" "app_logs" {
  name              = local.log_group_names.ecs_app
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.common.arn

  tags = merge(local.common_tags, {
    Name      = local.log_group_names.ecs_app
    Purpose   = "Application logs"
    Component = "logging"
  })
}

# X-Ray 데몬 로그 그룹
resource "aws_cloudwatch_log_group" "xray_logs" {
  name              = local.log_group_names.xray_daemon
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.common.arn

  tags = merge(local.common_tags, {
    Name      = local.log_group_names.xray_daemon
    Purpose   = "X-Ray daemon logs"
    Component = "monitoring"
  })
}

# ==========================================
# 공통 SNS 토픽 (알림용)
# ==========================================

# 공통 알림 토픽
resource "aws_sns_topic" "alerts" {
  name              = "${local.naming_convention.resource_name}-alerts"
  kms_master_key_id = aws_kms_key.common.arn

  tags = merge(local.common_tags, {
    Name      = "${local.naming_convention.resource_name}-alerts"
    Purpose   = "Common alerting topic"
    Component = "monitoring"
  })
}

# ==========================================
# 공통 Parameter Store 파라미터
# ==========================================

# 프로젝트 메타데이터
resource "aws_ssm_parameter" "project_metadata" {
  name = "${local.naming_convention.parameter}/metadata/project"
  type = "String"
  value = jsonencode({
    project_name = var.project_name
    environment  = var.environment
    region       = data.aws_region.current.id
    account_id   = data.aws_caller_identity.current.account_id
    created_at   = timestamp()
  })

  tags = merge(local.common_tags, {
    Name      = "${local.naming_convention.parameter}/metadata/project"
    Purpose   = "Project metadata"
    Component = "configuration"
  })
}

# 공통 설정
resource "aws_ssm_parameter" "common_config" {
  name = "${local.naming_convention.parameter}/common/config"
  type = "String"
  value = jsonencode({
    log_level          = var.default_log_level
    monitoring_enabled = var.monitoring_enabled
    backup_required    = var.backup_required
    kms_key_id         = aws_kms_key.common.arn
    sns_alerts_topic   = aws_sns_topic.alerts.arn
  })

  tags = merge(local.common_tags, {
    Name      = "${local.naming_convention.parameter}/common/config"
    Purpose   = "Common configuration"
    Component = "configuration"
  })
}

# ==========================================
# 공통 보안 정책 문서
# ==========================================

# ECS 태스크 실행 역할 신뢰 정책
data "aws_iam_policy_document" "ecs_task_execution_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# Lambda 실행 역할 신뢰 정책
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# CloudTrail 서비스 역할 신뢰 정책
data "aws_iam_policy_document" "cloudtrail_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
  }
}

# ==========================================
# 공통 보안 그룹 규칙 (참조용)
# ==========================================

# 공통 보안 그룹 규칙 정의 (다른 모듈에서 참조)
locals {
  common_security_rules = {
    # HTTP/HTTPS 규칙
    http_inbound = {
      type        = "ingress"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "HTTP inbound"
    }

    https_inbound = {
      type        = "ingress"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "HTTPS inbound"
    }

    # 애플리케이션 포트
    app_port_inbound = {
      type        = "ingress"
      from_port   = 8080
      to_port     = 8080
      protocol    = "tcp"
      description = "Application port inbound"
    }

    # MySQL 포트
    mysql_inbound = {
      type        = "ingress"
      from_port   = 3306
      to_port     = 3306
      protocol    = "tcp"
      description = "MySQL inbound"
    }

    # 모든 아웃바운드
    all_outbound = {
      type        = "egress"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
      description = "All outbound traffic"
    }
  }
}