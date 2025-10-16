# S3 Frontend Hosting Module
# 정적 웹사이트 호스팅을 위한 S3 버킷 생성 및 구성

# S3 버킷 생성
resource "aws_s3_bucket" "frontend" {
  bucket = "${var.name_prefix}-frontend-${var.environment}"

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-frontend-bucket"
    Environment = var.environment
    Purpose     = "frontend-hosting"
    ManagedBy   = "terraform"
  })
}

# S3 버킷 퍼블릭 액세스 차단 (CloudFront OAI 사용)
resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 버킷 버저닝 설정
resource "aws_s3_bucket_versioning" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Suspended"
  }
}

# S3 버킷 서버 사이드 암호화 설정
resource "aws_s3_bucket_server_side_encryption_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# S3 버킷 웹사이트 설정
resource "aws_s3_bucket_website_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

# CloudFront Origin Access Identity (OAI)
resource "aws_cloudfront_origin_access_identity" "frontend" {
  comment = "OAI for ${var.name_prefix} frontend S3 bucket"
}

# S3 버킷 정책 (CloudFront OAI만 접근 허용)
resource "aws_s3_bucket_policy" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCloudFrontAccess"
        Effect    = "Allow"
        Principal = {
          AWS = aws_cloudfront_origin_access_identity.frontend.iam_arn
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.frontend.arn}/*"
      }
    ]
  })
}

# CloudWatch 로그 그룹 (S3 액세스 로그용)
resource "aws_cloudwatch_log_group" "s3_access_logs" {
  count = var.enable_access_logging ? 1 : 0

  name              = "/aws/s3/${aws_s3_bucket.frontend.bucket}/access"
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Name    = "${var.name_prefix}-s3-access-logs"
    Service = "s3"
    Type    = "access-logs"
  })
}

# S3 버킷 로깅 설정
resource "aws_s3_bucket_logging" "frontend" {
  count = var.enable_access_logging ? 1 : 0

  bucket = aws_s3_bucket.frontend.id

  target_bucket = aws_s3_bucket.frontend.id
  target_prefix = "access-logs/"
}

# S3 버킷 CORS 설정 (필요시)
resource "aws_s3_bucket_cors_configuration" "frontend" {
  count = var.enable_cors ? 1 : 0

  bucket = aws_s3_bucket.frontend.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = var.cors_allowed_origins
    max_age_seconds = 3000
  }
}