# Parameter Store 모듈 - Spring Cloud Config Server 대체
# 중앙화된 설정 관리 및 보안 강화

# 현재 AWS 리전 정보
data "aws_region" "current" {}

# 공통 설정 파라미터
resource "aws_ssm_parameter" "common_config" {
  for_each = var.common_parameters

  name  = each.key
  type  = "String"
  value = each.value

  description = "PetClinic 공통 설정: ${split("/", each.key)[length(split("/", each.key)) - 1]}"

  tags = merge(var.tags, {
    Name        = each.key
    Environment = var.environment
    Type        = "common-configuration"
    Service     = "all"
  })
}

# 환경별 설정 파라미터
resource "aws_ssm_parameter" "environment_config" {
  for_each = var.environment_parameters

  name  = each.key
  type  = "String"
  value = each.value

  description = "PetClinic ${var.environment} 환경 설정: ${split("/", each.key)[length(split("/", each.key)) - 1]}"

  tags = merge(var.tags, {
    Name        = each.key
    Environment = var.environment
    Type        = "environment-configuration"
    Service     = split("/", each.key)[2]  # /petclinic/dev/service/key에서 service 추출
  })
}

# 보안 파라미터 (SecureString)
resource "aws_ssm_parameter" "secure_config" {
  for_each = var.secure_parameters

  name   = each.key
  type   = "SecureString"
  value  = each.value
  key_id = var.kms_key_id

  description = "PetClinic 보안 설정: ${split("/", each.key)[length(split("/", each.key)) - 1]}"

  tags = merge(var.tags, {
    Name        = each.key
    Environment = var.environment
    Type        = "secure-configuration"
    Service     = split("/", each.key)[2]  # /petclinic/dev/service/key에서 service 추출
  })
}

# 서비스별 설정 파라미터 (동적 생성)
resource "aws_ssm_parameter" "service_config" {
  for_each = var.service_specific_parameters

  name  = each.key
  type  = "String"
  value = each.value

  description = "PetClinic 서비스별 설정: ${split("/", each.key)[2]} - ${split("/", each.key)[length(split("/", each.key)) - 1]}"

  tags = merge(var.tags, {
    Name        = each.key
    Environment = var.environment
    Type        = "service-configuration"
    Service     = split("/", each.key)[2]
  })
}

# Parameter Store 접근을 위한 IAM 정책 (선택사항)
resource "aws_iam_policy" "parameter_store_read" {
  count = var.create_iam_policy ? 1 : 0

  name        = "${var.name_prefix}-parameter-store-read"
  description = "PetClinic Parameter Store 읽기 권한"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = [
          "arn:aws:ssm:${data.aws_region.current.name}:*:parameter${var.parameter_prefix}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = [
          var.kms_key_arn != "" ? var.kms_key_arn : "arn:aws:kms:${data.aws_region.current.name}:*:alias/aws/ssm"
        ]
      }
    ]
  })

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-parameter-store-policy"
    Environment = var.environment
    Type        = "iam-policy"
  })
}

# CloudWatch 로그 그룹 (Parameter Store 접근 로그용, 선택사항)
resource "aws_cloudwatch_log_group" "parameter_store_access" {
  count = var.enable_access_logging ? 1 : 0

  name              = "/aws/ssm/parameter-store/${var.name_prefix}"
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-parameter-store-logs"
    Environment = var.environment
    Type        = "logging"
  })
}