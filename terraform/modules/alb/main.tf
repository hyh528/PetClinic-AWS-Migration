data "aws_region" "current" {}

# ALB 보안 그룹
resource "aws_security_group" "alb" {
  name        = "${var.name_prefix}-alb-sg"
  description = "ALB용 보안 그룹"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-alb-sg"
    Environment = var.environment
    Tier        = "edge-lb"
  })
}

# IPv4 인그레스 80/443 (allow_ingress_cidrs_ipv4로 매개변수화)
resource "aws_vpc_security_group_ingress_rule" "alb_http_ipv4" {
  for_each = toset(var.allow_ingress_cidrs_ipv4)

  security_group_id = aws_security_group.alb.id

  description = "구성된 IPv4 CIDR에서 HTTP (80) 허용"
  cidr_ipv4   = each.value
  from_port   = 80
  to_port     = 80
  ip_protocol = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "alb_https_ipv4" {
  for_each = toset(var.allow_ingress_cidrs_ipv4)

  security_group_id = aws_security_group.alb.id

  description = "구성된 IPv4 CIDR에서 HTTPS (443) 허용"
  cidr_ipv4   = each.value
  from_port   = 443
  to_port     = 443
  ip_protocol = "tcp"
}

# IPv6 인그레스 80/443 (선택 사항)
resource "aws_vpc_security_group_ingress_rule" "alb_http_ipv6" {
  count = var.allow_ingress_ipv6_any ? 1 : 0

  security_group_id = aws_security_group.alb.id

  description = "IPv6 any에서 HTTP (80) 허용"
  cidr_ipv6   = "::/0"
  from_port   = 80
  to_port     = 80
  ip_protocol = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "alb_https_ipv6" {
  count = var.allow_ingress_ipv6_any ? 1 : 0

  security_group_id = aws_security_group.alb.id

  description = "IPv6 any에서 HTTPS (443) 허용"
  cidr_ipv6   = "::/0"
  from_port   = 443
  to_port     = 443
  ip_protocol = "tcp"
}

# 송신: 모두 허용 (나중에 ECS SG로 강화 가능)
resource "aws_vpc_security_group_egress_rule" "alb_all_out" {
  security_group_id = aws_security_group.alb.id

  description = "모든 아웃바운드 허용"
  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"
}

# 애플리케이션 로드 밸런서 (듀얼스택)
resource "aws_lb" "this" {
  name               = "${var.name_prefix}-alb"
  load_balancer_type = "application"
  internal           = false
  ip_address_type    = "dualstack"
  subnets            = var.public_subnet_ids
  security_groups    = [aws_security_group.alb.id]

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-alb"
    Environment = var.environment
    Tier        = "edge-lb"
  })
}

# ECS 태스크용 기본 대상 그룹 (awsvpc -> target_type ip)
resource "aws_lb_target_group" "default" {
  name        = "${var.name_prefix}-tg"
  port        = var.target_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    path                = var.health_check_path
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 30
    timeout             = 5
    matcher             = "200-399"
  }

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-tg"
    Environment = var.environment
  })
}

# 인증서가 있을 때 HTTP (80) 리스너를 HTTPS (443)로 리디렉션
resource "aws_lb_listener" "http_redirect" {
  count = var.create_http_redirect && var.certificate_arn != "" ? 1 : 0

  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# HTTPS가 아직 구성되지 않은 경우 HTTP (80) 리스너 포워딩 (폴백)
resource "aws_lb_listener" "http_forward" {
  count = var.create_http_redirect && var.certificate_arn != "" ? 0 : 1

  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.default.arn
  }
}

# ACM을 사용한 HTTPS (443) 리스너
resource "aws_lb_listener" "https" {
  count = var.certificate_arn != "" ? 1 : 0

  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"

  certificate_arn = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.default.arn
  }
}