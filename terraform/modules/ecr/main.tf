resource "aws_ecr_repository" "this" {
  for_each = toset(var.repository_names)

  name                 = each.key
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
    # 이미지가 푸시될 때마다 취약점 검사를 하도록 설정하는 보안 설정
  }

  tags = var.tags
}