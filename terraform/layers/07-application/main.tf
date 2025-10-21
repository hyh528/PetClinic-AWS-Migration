# =============================================================================
# Application Layer - 애플리케이션 인프라 (모듈 중심 설계)
# =============================================================================
# 목적: PetClinic의 4개 마이크로서비스를 위한 인프라 (모듈화된 접근 방식)
# 의존성: 01-network, 02-security, 03-database 레이어

# AWS 계정 정보
data "aws_caller_identity" "current" {}

# 공통 로컬 변수 (공유 변수 활용)

# =============================================================================
# ECR 모듈 (각 서비스별 리포지토리)
# =============================================================================

module "ecr_services" {
  for_each = local.services

  source = "../../modules/ecr"

  repository_name = "${var.name_prefix}-${each.key}"
  tags = merge(local.layer_common_tags, {
    Service = each.key
  })
}

# Docker 이미지 관리는 CI 파이프라인으로 이동했습니다.
# 이 레이어는 빌드된 이미지를 외부(예: CI)에서 전달받아 사용합니다.
# 권장: GitHub Actions 등을 사용해 이미지 빌드 → ECR 푸시 → Terraform에는
# immutable tag(예: git SHA 또는 digest)를 제공하세요.

# Terraform에서 사용할 서비스 이미지 매핑은 변수 `var.service_image_map` 를 통해 주입됩니다.
# 예: { customers = "123456789012.dkr.ecr.ap-southeast-2.amazonaws.com/petclinic-customers:sha-abc123" }

# =============================================================================
# ALB 모듈 (공통 로드 밸런서)
# =============================================================================

module "alb" {
  source = "../../modules/alb"

  name_prefix = var.name_prefix
  environment = var.environment

  vpc_id            = local.vpc_id
  public_subnet_ids = local.public_subnet_ids

  tags = local.layer_common_tags
}

# 각 서비스별 타겟 그룹 (ALB 모듈 외부에서 생성)
resource "aws_lb_target_group" "services" {
  for_each = local.services

  name        = "${var.name_prefix}-${each.key}"
  port        = each.value.port
  protocol    = "HTTP"
  vpc_id      = local.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    path                = each.value.health_path
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  tags = merge(local.layer_common_tags, {
    Service = each.key
  })
}

# 리스너 규칙 (호스트 기반 라우팅)
resource "aws_lb_listener_rule" "services" {
  for_each = local.services

  listener_arn = module.alb.listener_http_arn
  priority     = 100 + index(keys(local.services), each.key)

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.services[each.key].arn
  }

  condition {
    host_header {
      values = ["${each.key}.${var.name_prefix}.local"]
    }
  }

  tags = merge(local.layer_common_tags, {
    Service = each.key
  })
}

# =============================================================================
# ECS 클러스터
# =============================================================================

resource "aws_ecs_cluster" "main" {
  name = "${var.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = local.layer_common_tags
}

# CloudWatch 로그 그룹
resource "aws_cloudwatch_log_group" "services" {
  for_each = local.services

  name              = "/ecs/${var.name_prefix}-${each.key}"
  retention_in_days = 30

  tags = merge(local.layer_common_tags, {
    Service = each.key
  })
}

# =============================================================================
# ECS 서비스들 (각 마이크로서비스별)
# =============================================================================

resource "aws_ecs_task_definition" "services" {
  for_each = local.services

  family                   = "${var.name_prefix}-${each.key}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = each.value.cpu
  memory                   = each.value.memory
  execution_role_arn       = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/petclinic-ecs-task-execution-role"
  task_role_arn            = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/petclinic-ecs-task-execution-role"

  container_definitions = jsonencode([
    {
      name      = each.key
      image     = lookup(var.service_image_map, each.key, null)
      cpu       = each.value.cpu
      memory    = each.value.memory
      essential = true
      portMappings = [
        {
          containerPort = each.value.port
          hostPort      = each.value.port
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.services[each.key].name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
      command = [
        "/bin/sh",
        "-c",
        "echo '=== ECR DNS Resolution Test ===' && nslookup us-west-2.dkr.ecr.us-west-2.amazonaws.com && echo '=== ECR API DNS Test ===' && nslookup api.ecr.us-west-2.amazonaws.com && echo '=== ECR Auth Test ===' && timeout 10 aws ecr get-login-password --region us-west-2 && echo '=== Auth Success ===' || echo '=== Auth Failed ===' && echo '=== Network Test ===' && curl -I --connect-timeout 5 https://google.com && echo '=== Tests Complete - Starting Application ===' && exec java -jar app.jar"
      ]
      environment = [
        {
          name  = "SPRING_PROFILES_ACTIVE"
          value = "mysql,aws"
        },
        {
          name  = "AWS_ECR_DEBUG"
          value = "true"
        }
      ]
      # DNS 설정을 명시적으로 추가하여 Route 53 Resolver 강제 사용
      # dnsServers        = ["169.254.169.253"]  # awsvpc 모드에서는 지원되지 않음
      # dnsSearchDomains  = ["us-west-2.compute.internal"]
    }
  ])

  tags = merge(local.layer_common_tags, {
    Service = each.key
  })

  # 빌드는 CI로 분리되어 있으므로 null_resource 의존성을 제거합니다.
}

resource "aws_ecs_service" "services" {
  for_each = local.services

  name            = "${var.name_prefix}-${each.key}"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.services[each.key].arn
  desired_count   = 1

  launch_type = "FARGATE"

  network_configuration {
    subnets          = local.private_app_subnet_ids
    security_groups  = [local.ecs_security_group_id]
    assign_public_ip = false
  }

  # Enable execute command for debugging
  enable_execute_command = true

  load_balancer {
    target_group_arn = aws_lb_target_group.services[each.key].arn
    container_name   = each.key
    container_port   = each.value.port
  }

  tags = merge(local.layer_common_tags, {
    Service = each.key
  })

  depends_on = [aws_ecs_task_definition.services]
}

# =============================================================================
# Auto Scaling (선택사항 - 향후 확장 가능)
# =============================================================================

resource "aws_appautoscaling_target" "services" {
  for_each = local.services

  max_capacity       = 4
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.services[each.key].name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "cpu_scaling" {
  for_each = local.services

  name               = "${var.name_prefix}-${each.key}-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.services[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.services[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.services[each.key].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 70.0
  }
}
