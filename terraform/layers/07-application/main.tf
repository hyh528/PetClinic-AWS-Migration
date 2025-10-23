# =============================================================================
# Application Layer - 애플리케이션 인프라 (모듈 중심 설계)
# =============================================================================
# 목적: PetClinic의 4개 마이크로서비스를 위한 인프라 (모듈화된 접근 방식)
# 의존성: 01-network, 02-security, 03-database 레이어

# AWS 계정 정보
data "aws_caller_identity" "current" {}

# 공통 로컬 변수 (공유 변수 활용)

# =============================================================================
# EC2 인스턴스 - 데이터베이스 디버깅용
# =============================================================================

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

# Bastion Host (퍼블릭 서브넷)
resource "aws_instance" "bastion" {
  ami           = data.aws_ami.amazon_linux_2.id
  instance_type = "t3.micro"
  key_name      = "petclinic-debug"

  # 네트워크 설정 - 퍼블릭 서브넷에 배치
  subnet_id                   = local.public_subnet_ids[0]
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  associate_public_ip_address = true

  tags = merge(local.layer_common_tags, {
    Name = "${var.name_prefix}-bastion"
    Type = "bastion-host"
  })
}

# Bastion Host 보안 그룹
resource "aws_security_group" "bastion" {
  name_prefix = "${var.name_prefix}-bastion-"
  vpc_id      = local.vpc_id

  # SSH 인바운드 허용 (임시로 모든 IP에서 허용)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # 아웃바운드: 모든 트래픽 허용
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.layer_common_tags, {
    Name = "${var.name_prefix}-bastion-sg"
    Type = "bastion-security-group"
  })
}

resource "aws_instance" "db_debug" {
  ami           = data.aws_ami.amazon_linux_2.id
  instance_type = "t3.micro"
  key_name      = "petclinic-debug"

  # 네트워크 설정 - 프라이빗 서브넷 유지
  subnet_id                   = local.private_app_subnet_ids[0]
  vpc_security_group_ids      = [aws_security_group.db_debug.id]
  associate_public_ip_address = false

  # IAM 역할 (SSM 접근용)
  iam_instance_profile = aws_iam_instance_profile.db_debug.name

  # 사용자 데이터 (MySQL 클라이언트 설치 및 데이터베이스 연결 스크립트)
  user_data = base64encode(<<-EOF
    #!/bin/bash
    yum update -y
    amazon-linux-extras install -y epel
    yum install -y mysql
    yum install -y telnet
    yum install -y nc
    yum install -y jq
    yum install -y awscli

    # 데이터베이스 연결 정보 조회 및 연결 테스트
    echo "=== Database Connection Test ===" > /tmp/db_test.log

    # Parameter Store에서 DB 정보 조회
    DB_URL=$(aws ssm get-parameter --name "/petclinic/dev/db/url" --query "Parameter.Value" --output text --region us-west-2)
    DB_USERNAME=$(aws ssm get-parameter --name "/petclinic/dev/db/username" --query "Parameter.Value" --output text --region us-west-2)
    DB_SECRET_ARN=$(aws ssm get-parameter --name "/petclinic/dev/db/secrets-manager-name" --query "Parameter.Value" --output text --region us-west-2)

    echo "DB_URL: $DB_URL" >> /tmp/db_test.log
    echo "DB_USERNAME: $DB_USERNAME" >> /tmp/db_test.log
    echo "DB_SECRET_ARN: $DB_SECRET_ARN" >> /tmp/db_test.log

    # Secrets Manager에서 비밀번호 조회
    DB_PASSWORD=$(aws secretsmanager get-secret-value --secret-id "$DB_SECRET_ARN" --query "SecretString" --output text --region us-west-2 | jq -r '.password')

    echo "DB_PASSWORD retrieved successfully" >> /tmp/db_test.log

    # MySQL 연결 테스트
    echo "=== Testing MySQL Connection ===" >> /tmp/db_test.log
    mysql -h petclinic-dev-aurora-cluster.cluster-cr6g0qccsvqv.us-west-2.rds.amazonaws.com \
          -P 3306 \
          -u "$DB_USERNAME" \
          -p"$DB_PASSWORD" \
          -e "SHOW DATABASES;" >> /tmp/db_test.log 2>&1

    # petclinic 데이터베이스 확인
    echo "=== Checking petclinic database ===" >> /tmp/db_test.log
    mysql -h petclinic-dev-aurora-cluster.cluster-cr6g0qccsvqv.us-west-2.rds.amazonaws.com \
          -P 3306 \
          -u "$DB_USERNAME" \
          -p"$DB_PASSWORD" \
          -e "USE petclinic; SHOW TABLES;" >> /tmp/db_test.log 2>&1

    # 사용자 권한 확인
    echo "=== Checking user permissions ===" >> /tmp/db_test.log
    mysql -h petclinic-dev-aurora-cluster.cluster-cr6g0qccsvqv.us-west-2.rds.amazonaws.com \
          -P 3306 \
          -u "$DB_USERNAME" \
          -p"$DB_PASSWORD" \
          -e "SELECT User, Host FROM mysql.user WHERE User = '$DB_USERNAME';" >> /tmp/db_test.log 2>&1

    echo "=== Test Complete ===" >> /tmp/db_test.log
  EOF
  )

  tags = merge(local.layer_common_tags, {
    Name = "${var.name_prefix}-db-debug"
    Type = "db-debug-instance"
  })

  depends_on = [aws_security_group.db_debug]
}

# EC2용 보안 그룹 (Bastion Host에서 SSH 접근 허용)
resource "aws_security_group" "db_debug" {
  name_prefix = "${var.name_prefix}-db-debug-"
  vpc_id      = local.vpc_id

  # Bastion Host에서 SSH 접근 허용
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  # 아웃바운드: 모든 트래픽 허용 (NAT Gateway를 통해 인터넷 접근)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.layer_common_tags, {
    Name = "${var.name_prefix}-db-debug-sg"
    Type = "db-debug-security-group"
  })
}

# Aurora 보안 그룹에 EC2 인스턴스 접근 허용 규칙 추가
resource "aws_security_group_rule" "aurora_allow_db_debug" {
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  security_group_id        = local.aurora_security_group_id
  source_security_group_id = aws_security_group.db_debug.id

  description = "Allow MySQL access from DB debug EC2 instance"
}

# Aurora 보안 그룹에 ECS 태스크 접근 허용 규칙 추가
resource "aws_security_group_rule" "aurora_allow_ecs" {
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  security_group_id        = local.aurora_security_group_id
  source_security_group_id = local.ecs_security_group_id

  description = "Allow MySQL access from ECS tasks"
}

# EC2용 IAM 역할
resource "aws_iam_role" "db_debug" {
  name = "${var.name_prefix}-db-debug-role"

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

  tags = merge(local.layer_common_tags, {
    Name = "${var.name_prefix}-db-debug-role"
    Type = "iam-role"
  })
}

# Secrets Manager 접근 정책
resource "aws_iam_role_policy" "db_debug_secrets" {
  name = "${var.name_prefix}-db-debug-secrets-policy"
  role = aws_iam_role.db_debug.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          "arn:aws:secretsmanager:us-west-2:897722691159:secret:rds!cluster-*"
        ]
      }
    ]
  })
}

# SSM 정책 연결
resource "aws_iam_role_policy_attachment" "db_debug_ssm" {
  role       = aws_iam_role.db_debug.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Secrets Manager 접근 정책 추가
resource "aws_iam_role_policy_attachment" "db_debug_secrets" {
  role       = aws_iam_role.db_debug.name
  policy_arn = local.rds_secret_access_policy_arn
}

# Parameter Store 접근 정책 추가
resource "aws_iam_role_policy_attachment" "db_debug_params" {
  role       = aws_iam_role.db_debug.name
  policy_arn = local.parameter_store_access_policy_arn
}

# 인스턴스 프로파일
resource "aws_iam_instance_profile" "db_debug" {
  name = "${var.name_prefix}-db-debug-profile"
  role = aws_iam_role.db_debug.name

  tags = merge(local.layer_common_tags, {
    Name = "${var.name_prefix}-db-debug-profile"
    Type = "iam-instance-profile"
  })
}

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
      secrets = [
        {
          name      = "SPRING_DATASOURCE_URL"
          valueFrom = "/petclinic/${var.environment}/db/url"
        },
        {
          name      = "SPRING_DATASOURCE_USERNAME"
          valueFrom = "/petclinic/${var.environment}/db/username"
        },
        {
          name      = "SPRING_DATASOURCE_PASSWORD"
          valueFrom = "arn:aws:secretsmanager:us-west-2:897722691159:secret:rds!cluster-5b0f00bf-0fdd-49c7-93cc-80e45a006ec1-yzD4u2"
          secretId  = "arn:aws:secretsmanager:us-west-2:897722691159:secret:rds!cluster-5b0f00bf-0fdd-49c7-93cc-80e45a006ec1-yzD4u2"
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
    assign_public_ip = true
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
