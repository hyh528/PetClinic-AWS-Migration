# ==========================================
# Terraform 상태 관리 모듈
# ==========================================
# 클린 아키텍처 원칙: 상태 관리의 단일 책임

# ==========================================
# 환경별 S3 버킷 (상태 파일 저장)
# ==========================================
resource "aws_s3_bucket" "tfstate" {
  bucket        = var.bucket_name
  force_destroy = var.force_destroy

  tags = merge(var.tags, {
    Component = "terraform-state"
    Purpose   = "state-storage"
  })
}

# 버전 관리 활성화 (상태 파일 백업)
resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration {
    status = var.versioning_status
  }
}

# 서버 사이드 암호화 (KMS 키 사용)
resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.tfstate.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

# 퍼블릭 액세스 완전 차단
resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 라이프사이클 정책 (비용 최적화)
resource "aws_s3_bucket_lifecycle_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    id     = "tfstate_lifecycle"
    status = "Enabled"

    # 이전 버전 관리 (설정 가능한 일수)
    noncurrent_version_transition {
      noncurrent_days = var.lifecycle_rules.transition_to_ia_days
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_transition {
      noncurrent_days = var.lifecycle_rules.transition_to_glacier_days
      storage_class   = "GLACIER"
    }

    # 설정된 일수 후 이전 버전 삭제
    noncurrent_version_expiration {
      noncurrent_days = var.lifecycle_rules.expiration_days
    }
  }
}

# HTTPS 전용 액세스 정책
resource "aws_s3_bucket_policy" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyInsecureTransport"
        Effect = "Deny"
        Principal = "*"
        Action = "s3:*"
        Resource = [
          aws_s3_bucket.tfstate.arn,
          "${aws_s3_bucket.tfstate.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

# ==========================================
# KMS 키 (상태 파일 암호화)
# ==========================================
resource "aws_kms_key" "tfstate" {
  description             = "KMS key for Terraform state encryption"
  deletion_window_in_days = var.kms_key_deletion_window

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      }
    ]
  })

  tags = merge(var.tags, {
    Component = "terraform-state-encryption"
  })
}

resource "aws_kms_alias" "tfstate" {
  name          = "alias/${var.environment}-terraform-state"
  target_key_id = aws_kms_key.tfstate.key_id
}

# ==========================================
# DynamoDB 테이블 (상태 잠금)
# ==========================================
resource "aws_dynamodb_table" "tflock" {
  name         = var.lock_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  # Point-in-time recovery 활성화
  point_in_time_recovery {
    enabled = var.point_in_time_recovery
  }

  # 서버 사이드 암호화
  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.tfstate.arn
  }

  tags = merge(var.tags, {
    Component = "terraform-lock"
    Purpose   = "state-locking"
  })
}

# ==========================================
# 백업 및 복구 전략
# ==========================================

# S3 버킷 복제 (재해 복구용)
resource "aws_s3_bucket_replication_configuration" "tfstate" {
  count = var.enable_cross_region_replication ? 1 : 0

  role   = aws_iam_role.replication[0].arn
  bucket = aws_s3_bucket.tfstate.id

  rule {
    id     = "tfstate_replication"
    status = "Enabled"

    destination {
      bucket        = aws_s3_bucket.tfstate_replica[0].arn
      storage_class = "STANDARD_IA"

      encryption_configuration {
        replica_kms_key_id = aws_kms_key.tfstate_replica[0].arn
      }
    }
  }

  depends_on = [aws_s3_bucket_versioning.tfstate]
}

# 복제용 S3 버킷 (다른 리전)
resource "aws_s3_bucket" "tfstate_replica" {
  count = var.enable_cross_region_replication ? 1 : 0

  provider      = aws.replica
  bucket        = "${var.bucket_name}-replica"
  force_destroy = var.force_destroy

  tags = merge(var.tags, {
    Component = "terraform-state-replica"
    Purpose   = "disaster-recovery"
  })
}

# 복제용 KMS 키
resource "aws_kms_key" "tfstate_replica" {
  count = var.enable_cross_region_replication ? 1 : 0

  provider                = aws.replica
  description             = "KMS key for Terraform state replica encryption"
  deletion_window_in_days = var.kms_key_deletion_window

  tags = merge(var.tags, {
    Component = "terraform-state-replica-encryption"
  })
}

# 복제용 IAM 역할
resource "aws_iam_role" "replication" {
  count = var.enable_cross_region_replication ? 1 : 0

  name = "${var.environment}-tfstate-replication-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# 복제 권한 정책
resource "aws_iam_role_policy" "replication" {
  count = var.enable_cross_region_replication ? 1 : 0

  name = "${var.environment}-tfstate-replication-policy"
  role = aws_iam_role.replication[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetReplicationConfiguration",
          "s3:ListBucket"
        ]
        Resource = aws_s3_bucket.tfstate.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObjectVersionForReplication",
          "s3:GetObjectVersionAcl"
        ]
        Resource = "${aws_s3_bucket.tfstate.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete"
        ]
        Resource = "${aws_s3_bucket.tfstate_replica[0].arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = [
          aws_kms_key.tfstate.arn,
          aws_kms_key.tfstate_replica[0].arn
        ]
      }
    ]
  })
}

# 현재 AWS 계정 정보
data "aws_caller_identity" "current" {}