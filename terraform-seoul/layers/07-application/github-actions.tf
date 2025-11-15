# =============================================================================
# GitHub Actions IAM 역할 (CI/CD용)
# =============================================================================

# OIDC 공급자 (GitHub Actions용)
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

# GitHub Actions용 IAM 역할
resource "aws_iam_role" "github_actions_ecr" {
  name = "GitHubActions-PetClinic-ECR-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = data.aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:hyh528/PetClinic-AWS-Migration:*"
          }
        }
      }
    ]
  })

  tags = merge(local.layer_common_tags, {
    Purpose = "github-actions-ci-cd"
  })
}

# ECR 및 ECS 권한 정책
resource "aws_iam_role_policy" "github_actions_ecr_ecs" {
  name = "GitHubActions-ECR-ECS-Policy"
  role = aws_iam_role.github_actions_ecr.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # ECR 권한
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:GetRepositoryPolicy",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:DescribeImages",
          "ecr:BatchGetImage",
          "ecr:GetLifecycleConfiguration",
          "ecr:GetLifecyclePolicy",
          "ecr:GetLifecyclePolicyPreview",
          "ecr:ListTagsForResource",
          "ecr:DescribeImageScanFindings",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage",
          "ecr:PutImageTagMutability",
          "ecr:PutLifecycleConfiguration",
          "ecr:PutImageScanningConfiguration",
          "ecr:StartImageScan",
          "ecr:TagResource",
          "ecr:UntagResource",
          "ecr:DeleteLifecycleConfiguration",
          "ecr:BatchDeleteImage",
          "ecr:SetRepositoryPolicy",
          "ecr:DeleteRepository",
          "ecr:CreateRepository"
        ]
        Resource = "*"
      },
      # ECS 권한
      {
        Effect = "Allow"
        Action = [
          "ecs:UpdateService",
          "ecs:DescribeServices",
          "ecs:DescribeTasks",
          "ecs:ListTasks",
          "ecs:DescribeTaskDefinition",
          "ecs:RegisterTaskDefinition",
          "ecs:DeregisterTaskDefinition",
          "ecs:ListTaskDefinitions",
          "ecs:RunTask",
          "ecs:StopTask",
          "ecs:StartTask",
          "ecs:ExecuteCommand",
          "ecs:PutClusterCapacityProviders",
          "ecs:DeleteClusterCapacityProviders",
          "ecs:DescribeClusters",
          "ecs:ListClusters"
        ]
        Resource = "*"
      },
      # CloudWatch Logs 권한 (ECS 로그용)
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams",
          "logs:DescribeLogGroups",
          "logs:ListTagsLogGroup"
        ]
        Resource = "arn:aws:logs:*:*:log-group:/ecs/*"
      },
      # CloudWatch Metrics 권한 (모니터링용)
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",
          "cloudwatch:GetMetricData",
          "cloudwatch:ListMetrics"
        ]
        Resource = "*"
      },
      # Parameter Store 및 Secrets Manager 읽기 권한
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath",
          "ssm:DescribeParameters"
        ]
        Resource = "arn:aws:ssm:*:*:parameter/petclinic/*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "arn:aws:secretsmanager:*:*:secret:rds!cluster-*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = "arn:aws:kms:*:*:key/*"
      },
      # S3 상태 파일 저장소 (S3 네이티브 잠금 사용)
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.tfstate_bucket_name}",
          "arn:aws:s3:::${var.tfstate_bucket_name}/*"
        ]
      }
    ]
  })
}