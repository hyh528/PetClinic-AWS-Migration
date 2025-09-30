# ==========================================
# ECR (Elastic Container Registry) 모듈
# ==========================================
# Docker 이미지를 저장하고 관리하는 프라이빗 레지스트리
# 이미지 저장 책임 분리


# ECR 리포지토리 생성
resource "aws_ecr_repository" "this" {
  name                 = var.repository_name
  image_tag_mutability = var.image_tag_mutability

  # 보안: 이미지 푸시 시 자동 취약점 스캔
  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  tags = merge(var.tags, {
    Component = "ecr"
    Purpose   = "container-registry"
  })
}

# ECR 리포지토리 정책 (선택사항: 특정 IAM 사용자만 접근 허용)
resource "aws_ecr_repository_policy" "this" {
  repository = aws_ecr_repository.this.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowPushPull"
        Effect = "Allow"
        Principal = {
          AWS = "*"
        }
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
      }
    ]
  })
}

# ECR 라이프사이클 정책 (오래된 이미지 자동 삭제)
resource "aws_ecr_lifecycle_policy" "this" {
  count      = length(var.lifecycle_policy_rules) > 0 ? 1 : 0
  repository = aws_ecr_repository.this.name

  policy = jsonencode({
    rules = var.lifecycle_policy_rules
  })
}