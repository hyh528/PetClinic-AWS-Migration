# ==========================================
# Application 레이어: 클린 아키텍처 (모듈 조합)
# ==========================================
# 석겸이(seokgyeom)가 담당하는 모듈화된 애플리케이션 스택
# 각 모듈이 독립적인 책임을 가지며 조합하여 사용
#
# 클린 아키텍처 원칙:
# - 단일 책임: 각 모듈이 하나의 책임만 담당
# - 의존성 역전: 상위 모듈이 하위 모듈에 의존하지 않음
# - 개방-폐쇄: 모듈 확장이 용이
# - 인터페이스 분리: 모듈 간 계약이 명확
#
# 실행 순서:
# 1. terraform init    - 백엔드 및 프로바이더 초기화
# 2. terraform plan    - 변경사항 미리보기
# 3. terraform apply   - 모듈별 인프라 생성
# 4. Docker 이미지 빌드 및 ECR 푸시
# 5. ECS 서비스가 자동으로 새 이미지 배포

# ==========================================
# 1. ECR 모듈 호출 (이미지 저장소)
# ==========================================
# 책임: Docker 이미지 저장 및 보안 스캔
module "ecr" {
  source = "../../../modules/ecr"

  repository_name = "petclinic-app"

  tags = {
    Project     = "petclinic"
    Environment = "dev"
    Layer       = "application"
    ManagedBy   = "terraform"
    Owner       = "team-petclinic"
    CostCenter  = "training"
  }
}

# ==========================================
# 2. ALB 모듈 호출 (로드 밸런서)
# ==========================================
# 책임: 외부 트래픽 라우팅 및 분산
module "alb" {
  source = "../../../modules/alb"

  name_prefix = "petclinic-dev"
  environment = "dev"

  vpc_id            = data.terraform_remote_state.network.outputs.vpc_id
  public_subnet_ids = values(data.terraform_remote_state.network.outputs.public_subnet_ids)

  certificate_arn = ""

  allow_ingress_cidrs_ipv4 = ["0.0.0.0/0"]
  allow_ingress_ipv6_any   = true

  tags = {
    Project     = "petclinic"
    Environment = "dev"
    Layer       = "application"
    ManagedBy   = "terraform"
    Owner       = "team-petclinic"
    CostCenter  = "training"
  }
}

# ==========================================
# 3. ECS 모듈 호출 (컨테이너 실행)
# ==========================================
# 책임: 컨테이너 실행 환경 및 서비스 관리
module "ecs" {
  source = "../../../modules/ecs"

  cluster_name       = "petclinic-dev-cluster"
  task_family        = "petclinic-app"
  execution_role_arn = aws_iam_role.ecs_task_execution.arn

  # 컨테이너 설정 (JSON 형식)
  container_definitions = jsonencode([
    {
      name  = "petclinic-app"
      image = "${module.ecr.repository_url}:latest"

      portMappings = [
        {
          containerPort = 8080
          hostPort      = 8080
          protocol      = "tcp"
        }
      ]

      # 환경 변수 정의 (중복 키 제거, 하나의 리스트로 통합)
      environment = [
        {
          name  = "SPRING_PROFILES_ACTIVE"
          value = "mysql"
        },
        {
          name  = "DB_HOST"
          value = data.terraform_remote_state.database.outputs.cluster_endpoint
        },
        {
          name  = "DB_PORT"
          value = tostring(data.terraform_remote_state.database.outputs.cluster_port)
        },
        {
          name  = "DB_NAME"
          value = "petclinic_customers"
        },
        {
          name  = "DB_USERNAME"
          value = "petclinic"
        }
      ]

      # ==========================================
      # 민감한 정보 처리 (실무 DevOps 표준)
      # ==========================================
      # 1. 시크릿은 Terraform 외부에서 생성/관리
      # 2. Terraform에서는 data source로 참조만 함
      # 3. 장점:
      #    - 시크릿 값이 Terraform state에 저장되지 않음
      #    - CI/CD 파이프라인에서 안전하게 관리 가능
      #    - 환경별로 다른 시크릿 사용 가능
      #    - 감사 및 로테이션 용이
      #
      # ECS 태스크 실행 역할에 다음 정책 필요:
      # {
      #   "Version": "2012-10-17",
      #   "Statement": [
      #     {
      #       "Effect": "Allow",
      #       "Action": "secretsmanager:GetSecretValue",
      #       "Resource": "arn:aws:secretsmanager:ap-northeast-2:ACCOUNT:secret:petclinic/dev/db-password-*"
      #     }
      #   ]
      # }
      # ==========================================
      secrets = [
        {
          name      = "DB_PASSWORD"
          valueFrom = data.aws_secretsmanager_secret_version.db_password.arn
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/petclinic-app"
          "awslogs-region"        = "ap-northeast-2"
          "awslogs-stream-prefix" = "ecs"
        }
      }

      healthCheck = {
        command  = ["CMD-SHELL", "curl -f http://localhost:8080/actuator/health || exit 1"]
        interval = 30
        timeout  = 5
        retries  = 3
      }
    }
  ])

  cpu           = "256"
  memory        = "512"
  desired_count = 2

  subnets          = values(data.terraform_remote_state.network.outputs.private_app_subnet_ids)
  security_groups  = [data.terraform_remote_state.security.outputs.ecs_security_group_id] # Security 레이어 SG 연동
  target_group_arn = module.alb.default_target_group_arn
  container_name   = "petclinic-app"
  container_port   = 8080

  tags = {
    Project     = "petclinic"
    Environment = "dev"
    Layer       = "application"
    ManagedBy   = "terraform"
    Owner       = "team-petclinic"
    CostCenter  = "training"
  }
}

# ==========================================
# 4. ECS 태스크 실행 역할 (IAM)
# ==========================================
# 책임: ECS 태스크의 AWS 서비스 접근 권한 관리
resource "aws_iam_role" "ecs_task_execution" {
  name = "petclinic-dev-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Project     = "petclinic"
    Environment = "dev"
    Layer       = "application"
    ManagedBy   = "terraform"
    Owner       = "team-petclinic"
    CostCenter  = "training"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}