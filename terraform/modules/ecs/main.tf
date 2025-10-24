# 1. CloudWatch Log Group (서비스별 로그)
resource "aws_cloudwatch_log_group" "service" {
  name              = "/ecs/petclinic/${var.service_name}"
  retention_in_days = 7
}

# 2. Target Group (서비스별로 생성)
resource "aws_lb_target_group" "service" {
  name        = "tg-${var.service_name}"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/actuator/health"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# 3. Listener Rule (서비스별로 생성)
resource "aws_lb_listener_rule" "service" {
  listener_arn = var.listener_arn # application 레이어에서 전달받음
  priority     = var.listener_priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.service.arn
  }

  condition {
    path_pattern {
      # 예: /customers-service/* 요청을 이 서비스로 라우팅
      values = ["/${var.service_name}/*"]
    }
  }
}

# 4. ECS Task Definition (서비스별 청사진)
resource "aws_ecs_task_definition" "service" {
  family                   = "${var.service_name}-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = var.ecs_task_execution_role_arn # application 레이어에서 전달받음
  task_role_arn            = var.task_role_arn
  
  container_definitions = jsonencode([
    {
      name      = var.service_name,
      image     = var.image_uri,
        cpu       = tonumber(var.task_cpu),
     memory    = tonumber(var.task_memory),
     essential = true,
      portMappings = [
        {
          containerPort = var.container_port,
          hostPort      = var.container_port
        }
      ],
      environment = [
        for k, v in var.environment_variables : {
          name  = k,
          value = v
        }
      ],
      secrets = [                                     
        {                                             
          name      = "SPRING_DATASOURCE_PASSWORD",   
          valueFrom = var.db_master_user_secret_arn      
        },
                {                                             
          name      = "SPRING_DATASOURCE_URL",   
          valueFrom = var.db_url_parameter_path      
        },
                {                                             
          name      = "SPRING_DATASOURCE_USERNAME",   
          valueFrom = var.db_username_parameter_path      
        }                                                                                     
      ],                                                                                     
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.service.name,
          "awslogs-region"        = var.aws_region,
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

# 5. ECS Service (서비스 실행 및 관리)
resource "aws_ecs_service" "service" {
  name            = var.service_name
  cluster         = var.cluster_id # application 레이어에서 전달받음
  task_definition = aws_ecs_task_definition.service.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  service_registries {
    # cloudmap_service_arn이 null이 아닐 때만 이 블록을 활성화
    registry_arn = var.cloudmap_service_arn
  }

  network_configuration {
    subnets         = var.private_subnet_ids
    security_groups = [var.ecs_service_sg_id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.service.arn
    container_name   = var.service_name
    container_port   = var.container_port
  }

  depends_on = [aws_lb_listener_rule.service]
}