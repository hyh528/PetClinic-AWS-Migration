# ==========================================
# Terraform 부트스트랩 구성 (Oregon 리전)
# ==========================================
# 이 파일은 Terraform의 백엔드 인프라(S3 + DynamoDB)를 생성합니다.
# Bootstrap은 Terraform이 Terraform을 관리하는 "부트스트래핑" 개념입니다.

# ==========================================
# Terraform 원격 상태를 위한 S3 버킷
# ==========================================
# Terraform 상태 파일을 안전하게 저장하는 S3 버킷 생성

# 1. 기본 S3 버킷 생성
resource "aws_s3_bucket" "tfstate" {
  # 버킷 이름 (전 세계적으로 고유해야 함)
  bucket = var.tfstate_bucket_name

  # 강제 삭제 허용 (상태 파일들 자동 삭제)
  force_destroy = true

  # 리소스 태그 (식별과 관리용)
  tags = {
    Name        = var.tfstate_bucket_name
    Description = "Petclinic Terraform remote state bucket Seoul"
  }
}

# 2. 퍼블릭 액세스 완전 차단 (보안 필수)
# Terraform 상태 파일은 매우 민감한 정보이므로 외부 접근 금지!!
resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  # 모든 퍼블릭 액세스 차단
  block_public_acls       = true # 공개 ACL 차단
  block_public_policy     = true # 공개 버킷 정책 차단
  ignore_public_acls      = true # 기존 공개 ACL 무시
  restrict_public_buckets = true # 퍼블릭 버킷 제한
}

# 3. 버전 관리 활성화 (안전한 백업)
# 실수로 상태 파일을 덮어써도 이전 버전으로 복구 가능
resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration {
    status = "Enabled" # 버전 관리 켜기
  }
}

# 4. 저장 시 자동 암호화 (SSE-S3)
# 상태 파일을 AES256으로 암호화하여 저장
resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256" # AWS 관리 키로 암호화
    }
  }
}

# 5. SSL/TLS 전용 액세스 강제 (보안 강화)
# HTTP 대신 HTTPS만 허용하여 데이터 전송 암호화
data "aws_iam_policy_document" "tfstate_deny_insecure_transport" {
  statement {
    sid     = "DenyInsecureTransport" # 정책 고유 식별자
    effect  = "Deny"                  # 이 조건에 맞으면 거부
    actions = ["s3:*"]                # 모든 S3 작업에 적용
    principals {                      # 모든 사용자/역할에 적용
      type        = "*"
      identifiers = ["*"]
    }
    resources = [ # 버킷과 객체 모두 적용
      aws_s3_bucket.tfstate.arn,
      "${aws_s3_bucket.tfstate.arn}/*"
    ]
    condition { # 조건: HTTPS가 아닌 경우
      test     = "Bool"
      variable = "aws:SecureTransport" # AWS 보안 전송 플래그
      values   = ["false"]             # false면 (HTTP면) 거부
    }
  }
}

# S3 버킷에 정책 적용
resource "aws_s3_bucket_policy" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  policy = data.aws_iam_policy_document.tfstate_deny_insecure_transport.json
}

# ==========================================
# S3 네이티브 상태 잠금 (Terraform 1.10.0+)
# ==========================================
# DynamoDB 대신 S3의 네이티브 잠금 기능을 사용
# 더 간단하고 비용 효율적임

resource "aws_s3_bucket_versioning" "tfstate_locking" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration {
    status = "Enabled"
  }
}

# ==========================================
# Bootstrap 완료 후 다음 단계
# ==========================================
# 1. terraform output으로 값 확인
# 2. envs/dev/network/providers.tf의 backend 설정 확인
# 3. terraform init (백엔드 전환)
# 4. terraform apply (실제 인프라 생성)