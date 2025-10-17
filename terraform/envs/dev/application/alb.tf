# terraform/envs/dev/application/alb.tf

resource "aws_lb" "main" {
  name               = "petclinic-main-alb"
  internal           = false
  load_balancer_type = "application"
  # security 레이어에서 가져온 ALB 보안 그룹 ID 사용
  security_groups    = [data.terraform_remote_state.security.outputs.alb_security_group_id]
  # network 레이어에서 가져온 Public Subnet ID들 사용
  subnets            = values(data.terraform_remote_state.network.outputs.public_subnet_ids)

  tags = {
    Name = "petclinic-main-alb"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  # default_action: 어떤 리스너 규칙과도 맞지 않을 때 기본적으로 수행할 동작
  # 여기서는 404 Not Found 응답을 보냅니다.
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Cannot route request."
      status_code  = "404"
    }
  }
}