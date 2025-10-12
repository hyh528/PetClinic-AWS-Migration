# =============================================================================
# Application Layer - 애플리케이션 인프라 (모듈 중심 설계)
# =============================================================================
# 목적: PetClinic의 4개 마이크로서비스를 위한 인프라 (모듈화된 접근 방식)
# 의존성: 01-network, 02-security, 03-database 레이어

# AWS 계정 정보
data "aws_caller_identity" "current" {}

# 공통 로컬 변수 (공유 변수 활용)
locals {
  # Network 레이어에서 필요한 정보
  vpc_id                 = data.terraform_remote_state.network.outputs.vpc_id
  public_subnet_ids      = values(data.terraform_remote_state.network.outputs.public_subnet_ids)
  private_app_subnet_ids = values(data.terraform_remote_state.network.outputs.private_app_subnet_ids)

  # Security 레이어에서 필요한 정보
  ecs_security_group_id = data.terraform_remote_state.security.outputs.ecs_security_group_id

  # 공통 태그 (공유 변수 활용)
  layer_common_tags = merge(var.shared_config.common_tags, {
    Layer     = "07-application"
    Component = "application-infrastructure"
  })

  # 서비스 정의 (환경별 설정 가능)
  services = {
    customers = {
      name          = "customers-service"
      port          = 8081
      health_path   = "/actuator/health"
      cpu           = 256
      memory        = 512
    }
    vets = {
      name          = "vets-service"
      port          = 8082
      health_path   = "/actuator/health"
      cpu           = 256
      memory        = 512
    }
    visits = {
      name          = "visits-service"
      port          = 8083
      health_path   = "/actuator/health"
      cpu           = 256
      memory        = 512
    }
    admin = {
      name          = "admin-server"
      port          = 9090
      health_path   = "/actuator/health"
      cpu           = 256
      memory        = 512
    }
  }

  # 서비스별 디렉토리 매핑 (실제 디렉토리 이름과 매핑)
  service_directories = {
    customers = "customers-service"
    vets      = "vets-service"
    visits    = "visits-service"
    admin     = "admin-server"
  }
}

# =============================================================================
# ECR 모듈 (각 서비스별 리포지토리)
# =============================================================================

module "ecr_services" {
  for_each = local.services

  source = "../../modules/ecr"

  repository_name = "${var.shared_config.name_prefix}-${each.key}"
  tags            = merge(local.layer_common_tags, {
    Service = each.key
  })
}

# =============================================================================
# Docker 이미지 빌드 및 푸시 (모듈화된 접근 방식)
# =============================================================================

resource "null_resource" "build_and_push_images" {
  for_each = local.services

  depends_on = [module.ecr_services]

  provisioner "local-exec" {
    working_dir = "../../../"
    command = <<-EOT
      echo "Building and pushing ${each.key} service image..."

      # ECR 로그인 및 이미지 빌드/푸시
      cd spring-petclinic-${local.service_directories[each.key]}
      ../mvnw compile jib:build -Dimage=${module.ecr_services[each.key].repository_url}:latest

      echo "${each.key} service image pushed successfully"
    EOT
  }

  triggers = {
    source_hash = filemd5("../../../spring-petclinic-${local.service_directories[each.key]}/pom.xml")
    always_run  = timestamp()
  }
}

# =============================================================================
# ALB 모듈 (공통 로드 밸런서)
# =============================================================================

module "alb" {
  source = "../../modules/alb"

  name_prefix = var.shared_config.name_prefix
  environment = var.shared_config.environment

  vpc_id            = local.vpc_id
  public_subnet_ids = local.public_subnet_ids

  tags = local.layer_common_tags
}

# 각 서비스별 타겟 그룹 (ALB 모듈 외부에서 생성)
resource "aws_lb_target_group" "services" {
  for_each = local.services

  name        = "${var.shared_config.name_prefix}-${each.key}"
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
      values = ["${each.key}.${var.shared_config.name_prefix}.local"]
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
  name = "${var.shared_config.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = local.layer_common_tags
}

# CloudWatch 로그 그룹
resource "aws_cloudwatch_log_group" "services" {
  for_each = local.services

  name              = "/ecs/${var.shared_config.name_prefix}-${each.key}"
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

  family                   = "${var.shared_config.name_prefix}-${each.key}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = each.value.cpu
  memory                   = each.value.memory
  execution_role_arn       = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/ecsTaskExecutionRole"

  container_definitions = jsonencode([
    {
      name  = each.key
      image = "${module.ecr_services[each.key].repository_url}:latest"
      cpu   = each.value.cpu
      memory = each.value.memory
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
          "awslogs-region"        = var.shared_config.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
      environment = [
        {
          name  = "SPRING_PROFILES_ACTIVE"
          value = "mysql,aws"
        }
      ]
    }
  ])

  tags = merge(local.layer_common_tags, {
    Service = each.key
  })

  depends_on = [null_resource.build_and_push_images]
}

resource "aws_ecs_service" "services" {
  for_each = local.services

  name            = "${var.shared_config.name_prefix}-${each.key}"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.services[each.key].arn
  desired_count   = 1

  launch_type = "FARGATE"

  network_configuration {
    subnets         = local.private_app_subnet_ids
    security_groups = [local.ecs_security_group_id]
  }

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

  name               = "${var.shared_config.name_prefix}-${each.key}-cpu-scaling"
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