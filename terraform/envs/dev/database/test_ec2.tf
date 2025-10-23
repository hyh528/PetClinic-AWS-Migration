# 이 파일은 Aurora DB 테스트용 임시 EC2 인스턴스를 정의합니다.

# 테스트 EC2 인스턴스용 보안 그룹
resource "aws_security_group" "test_ec2_sg" {
  name        = "petclinic-test-ec2-sg-dev"
  description = "Security group for the test EC2 instance"
  vpc_id      = data.terraform_remote_state.network.outputs.vpc_id

  # 모든 아웃바운드 트래픽 허용
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "petclinic-test-ec2-sg-dev"
  }
}

# EC2가 사용할 IAM 역할 및 정책
resource "aws_iam_role" "test_ec2_role" {
  name = "petclinic-test-ec2-role-dev"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "test_ec2_policy" {
  name        = "petclinic-test-ec2-policy-dev"
  description = "Allow EC2 to read DB credentials"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameters",
          "ssm:GetParameter"
        ]
        Resource = [
          aws_ssm_parameter.common_db_url.arn,
          aws_ssm_parameter.common_db_username.arn
        ]
      },
      {
        Effect   = "Allow"
        Action   = "secretsmanager:GetSecretValue"
        Resource = aws_rds_cluster.petclinic_aurora_cluster.master_user_secret[0].secret_arn
      },
      {
        Effect   = "Allow"
        Action   = "kms:Decrypt"
        Resource = aws_kms_key.aurora_secrets.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "test_ec2_attach" {
  role       = aws_iam_role.test_ec2_role.name
  policy_arn = aws_iam_policy.test_ec2_policy.arn
}

resource "aws_iam_instance_profile" "test_ec2_profile" {
  name = "petclinic-test-ec2-profile-dev"
  role = aws_iam_role.test_ec2_role.name
}

# 최신 Amazon Linux 2 AMI 검색
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# 테스트용 EC2 인스턴스
resource "aws_instance" "db_test_instance" {
  ami           = data.aws_ami.amazon_linux_2.id
  instance_type = "t2.micro"
  
  key_name      = "pjj_petclinic_test"

  subnet_id     = values(data.terraform_remote_state.network.outputs.private_db_subnet_ids)[0]
  
  vpc_security_group_ids = [aws_security_group.test_ec2_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.test_ec2_profile.name

  tags = {
    Name = "petclinic-db-test-instance-dev"
  }
}