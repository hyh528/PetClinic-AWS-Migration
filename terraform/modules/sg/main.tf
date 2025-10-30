# 보안 그룹 모듈 메인 파일
# 이 파일은 다양한 유형의 보안 그룹 (ALB, App, DB, VPCE)을 생성합니다.

# 1. ALB (Application Load Balancer)용 보안 그룹
resource "aws_security_group" "alb" {
  # sg_type이 "alb"일 때만 이 리소스를 생성합니다.
  count = var.sg_type == "alb" ? 1 : 0

  name        = "${var.name_prefix}-alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = var.vpc_id

  # 인바운드 규칙: HTTP (80) 및 HTTPS (443) 트래픽을 모든 곳에서 허용
  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP from anywhere"
  }
  ingress {
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS from anywhere"
  }
  # 아웃바운드 규칙: 모든 트래픽을 허용
  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }



  tags = merge(
    var.tags,
    { "Name" = "${var.name_prefix}-alb-sg" }
  )
}


# 2. APP (Application / ECS)용 보안 그룹
resource "aws_security_group" "app" {
  # sg_type이 "app"일 때만 이 리소스를 생성합니다.
  count = var.sg_type == "app" ? 1 : 0

  name        = "${var.name_prefix}-app-sg"
  description = "Security group for Application (ECS)"
  vpc_id      = var.vpc_id



  # 아웃바운드 규칙: 모든 트래픽을 허용
  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    { "Name" = "${var.name_prefix}-app-sg" }
  )
}


# 3. DB (Database / Aurora)용 보안 그룹
resource "aws_security_group" "db" {
  # sg_type이 "db"일 때만 이 리소스를 생성합니다.
  count = var.sg_type == "db" ? 1 : 0

  name        = "${var.name_prefix}-db-sg"
  description = "Security group for Database (Aurora)"
  vpc_id      = var.vpc_id

  # 인바운드 규칙: APP 보안 그룹으로부터의 MySQL/Aurora (3306) 트래픽만 허용
  ingress {
    protocol        = "tcp"
    from_port       = 3306
    to_port         = 3306
    security_groups = [var.app_source_security_group_id]
    description     = "MySQL/Aurora traffic from App"
  }

  # 아웃바운드 규칙: DB는 일반적으로 아웃바운드 연결이 필요 없음 (보안 강화)
  # 필요시에만 특정 규칙 추가

  tags = merge(
    var.tags,
    { "Name" = "${var.name_prefix}-db-sg" }
  )
}


# 4. VPCE (VPC Endpoint)용 보안 그룹
resource "aws_security_group" "vpce" {
  # sg_type이 "vpce"일 때만 이 리소스를 생성합니다.
  count = var.sg_type == "vpce" ? 1 : 0

  name        = "${var.name_prefix}-vpce-sg"
  description = "Security group for VPC Endpoints"
  vpc_id      = var.vpc_id

  # 인바운드 규칙: VPC 내부에서 443 포트 (HTTPS) 트래픽을 허용
  ingress {
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = [var.vpc_cidr]
    description = "HTTPS for VPCE from within VPC"
  }

  # 아웃바운드 규칙: VPC 내부로의 모든 트래픽을 허용
  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = [var.vpc_cidr]
    description = "All outbound traffic within VPC"
  }

  tags = merge(
    var.tags,
    { "Name" = "${var.name_prefix}-vpce-sg" }
  )
}
