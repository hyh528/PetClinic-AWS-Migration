# /terraform/envs/dev/security/iam-policies.tf

# =================================================================================
# IAM Policy for Application Access to RDS Secrets
# =================================================================================
#
# 이 정책은 애플리케이션(예: EC2, ECS Task)이 Secrets Manager에 저장된 
# RDS 데이터베이스의 자격 증명(비밀번호)을 읽을 수 있도록 허용합니다.
#
# 연결 대상: 애플리케이션의 IAM 역할 (예: petclinic-dev-app-role)
#
resource "aws_iam_policy" "rds_secret_access" {
  # 이름에 환경(dev)을 명시하여 어떤 환경의 정책인지 명확히 합니다.
  name = "petclinic-dev-rds-secret-access"
  
  description = "Allows application access to RDS secrets in the dev environment"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          # 시크릿 값을 읽어오는 가장 핵심적인 권한
          "secretsmanager:GetSecretValue",
          # 시크릿의 메타데이터를 읽는 권한 (예: ARN, 설명 등)
          "secretsmanager:DescribeSecret"
        ]
        # dev 환경의 모든 RDS 관련 시크릿에 접근을 허용합니다.
        # "rds-db-credentials/" 접두사를 가진 시크릿으로 범위를 제한하여 보안을 강화합니다.
        Resource = "arn:aws:secretsmanager:*:*:secret:rds-db-credentials/*"
      }
    ]
  })

  tags = {
    Environment = "dev"
    ManagedBy   = "Terraform"
    Service     = "petclinic"
  }
}
