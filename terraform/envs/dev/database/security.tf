resource "aws_kms_key" "aurora_secrets" {
  description             = "KMS key for encrypting Aurora secrets in Secrets Manager"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Name = "kms-aurora-secrets-dev"
  }
}
