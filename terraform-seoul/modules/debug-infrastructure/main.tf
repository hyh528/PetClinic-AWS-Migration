# =============================================================================
# Bastion Host Module
# =============================================================================
# 목적: 개발 및 디버깅을 위한 Bastion Host (SSH 접근 및 DB 디버깅)
# 조건부 생성: enable_debug_infrastructure 변수로 제어

# 최신 Amazon Linux 2 AMI 조회
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

# =============================================================================
# Bastion Host (퍼블릭 서브넷)
# =============================================================================

resource "aws_instance" "bastion" {
  count = var.enable_debug_infrastructure ? 1 : 0

  ami           = data.aws_ami.amazon_linux_2.id
  instance_type = var.bastion_instance_type
  key_name      = var.key_pair_name

  # 네트워크 설정 - 퍼블릭 서브넷에 배치
  subnet_id                   = var.public_subnet_ids[0]
  vpc_security_group_ids      = [aws_security_group.bastion[0].id]
  associate_public_ip_address = true

  # IAM 역할 (SSM, Secrets Manager, Parameter Store 접근용)
  iam_instance_profile = aws_iam_instance_profile.bastion[0].name

  # 사용자 데이터 (MySQL 클라이언트 및 디버깅 도구 설치)
  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    aws_region          = var.aws_region
    db_cluster_endpoint = var.db_cluster_endpoint
  }))

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-bastion"
    Type = "bastion-host"
  })
}

# Bastion Host 보안 그룹
resource "aws_security_group" "bastion" {
  count = var.enable_debug_infrastructure ? 1 : 0

  name_prefix = "${var.name_prefix}-bastion-"
  vpc_id      = var.vpc_id

  # SSH 인바운드 허용 (지정된 CIDR에서만)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.bastion_allowed_cidrs
    description = "SSH access to bastion host"
  }

  # 아웃바운드: 모든 트래픽 허용
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-bastion-sg"
    Type = "bastion-security-group"
  })
}

# Aurora 보안 그룹에 Bastion Host 접근 허용 규칙 추가
resource "aws_security_group_rule" "aurora_allow_bastion" {
  count = var.enable_debug_infrastructure ? 1 : 0

  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  security_group_id        = var.aurora_security_group_id
  source_security_group_id = aws_security_group.bastion[0].id

  description = "Allow MySQL access from Bastion host"
}

# =============================================================================
# IAM 역할 및 정책 (Bastion Host용)
# =============================================================================

# Bastion Host용 IAM 역할
resource "aws_iam_role" "bastion" {
  count = var.enable_debug_infrastructure ? 1 : 0

  name = "${var.name_prefix}-bastion-role"

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

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-bastion-role"
    Type = "iam-role"
  })
}

# Secrets Manager 접근 정책
resource "aws_iam_role_policy" "bastion_secrets" {
  count = var.enable_debug_infrastructure ? 1 : 0

  name = "${var.name_prefix}-bastion-secrets-policy"
  role = aws_iam_role.bastion[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          "arn:aws:secretsmanager:${var.aws_region}:*:secret:rds!cluster-*"
        ]
      }
    ]
  })
}

# SSM 정책 연결
resource "aws_iam_role_policy_attachment" "bastion_ssm" {
  count = var.enable_debug_infrastructure ? 1 : 0

  role       = aws_iam_role.bastion[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Secrets Manager 접근 정책 추가
resource "aws_iam_role_policy_attachment" "bastion_secrets" {
  count = var.enable_debug_infrastructure ? 1 : 0

  role       = aws_iam_role.bastion[0].name
  policy_arn = var.rds_secret_access_policy_arn
}

# Parameter Store 접근 정책 추가
resource "aws_iam_role_policy_attachment" "bastion_params" {
  count = var.enable_debug_infrastructure ? 1 : 0

  role       = aws_iam_role.bastion[0].name
  policy_arn = var.parameter_store_access_policy_arn
}

# 인스턴스 프로파일
resource "aws_iam_instance_profile" "bastion" {
  count = var.enable_debug_infrastructure ? 1 : 0

  name = "${var.name_prefix}-bastion-profile"
  role = aws_iam_role.bastion[0].name

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-bastion-profile"
    Type = "iam-instance-profile"
  })
}
