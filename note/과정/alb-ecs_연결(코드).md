# 현 프로젝트의 ALB-ECS 연결 방식 상세 분석

이 문서는 현재 PetClinic 프로젝트의 Terraform 코드를 기반으로, `alb-ecs_연결방법(기본틀).md` 문서의 개념이 실제 코드로 어떻게 구현되었는지 상세히 설명합니다.

## 전체 구조: 레이어(Layer) 분리

가장 먼저, 우리 프로젝트는 인프라를 역할에 따라 여러 **레이어(Layer)**로 나누어 관리합니다. 이것은 매우 좋은 설계 방식입니다.

- `bootstrap`: Terraform 자체를 관리하기 위한 인프라 (S3, DynamoDB)를 생성합니다. (최초 1회 실행)
- `envs/dev/network`: VPC, 서브넷 등 네트워크 기반을 담당합니다.
- `envs/dev/security`: 보안 그룹, IAM 역할, VPC 엔드포인트 등 보안 설정을 담당합니다.
- `envs/dev/application`: ALB, ECS 클러스터, 서비스 배포 등 실제 애플리케이션을 담당합니다.

이 레이어들은 `data "terraform_remote_state"`를 통해 서로의 결과물(output)을 참조하며 유기적으로 연결됩니다. `application/data.tf` 파일에서 다른 레이어의 `tfstate`를 읽어오는 부분이 바로 이 '접착제' 역할을 합니다.

---

## `application` 레이어에서의 실제 연결 과정

`terraform/envs/dev/application/` 디렉터리를 중심으로 실제 연결이 어떻게 이루어지는지 단계별로 살펴보겠습니다.

### 1단계: 공유 리소스 생성

문서에서 설명한 것처럼, 여러 서비스가 함께 사용할 **공유 리소스**를 `application` 레이어에서 먼저 생성합니다.

#### 📄 `terraform/envs/dev/application/alb.tf`
이 파일은 모든 서비스가 공유하는 ALB와 리스너를 생성합니다.
```terraform
# 1. 메인 ALB 생성
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

# 2. 기본 리스너 생성 (HTTP:80)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  # 일치하는 규칙이 없을 때의 기본 동작
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Cannot route request."
      status_code  = "404"
    }
  }
}
```

#### 📄 `terraform/envs/dev/application/cluster.tf`
모든 서비스 컨테이너가 배포될 공용 ECS 클러스터를 생성합니다.
```terraform
resource "aws_ecs_cluster" "main" {
  name = "petclinic-cluster"
}
```

### 2단계: `ecs` 모듈에 공유 리소스 정보 전달

이제 각 서비스를 배포할 차례입니다. `ecs.tf` 파일에서 `for_each`를 사용해 각 서비스 모듈을 호출하며, 1단계에서 만든 공유 리소스의 정보를 전달합니다.

#### 📄 `terraform/envs/dev/application/ecs.tf`
```terraform
# for_each를 사용하여 서비스별로 ecs 모듈 호출
module "ecs" {
  for_each = local.ecs_services
  source   = "../../../modules/ecs"
  
  # ... (DB, 네트워크, 보안 그룹 등 다른 정보 전달) ...

  # --- ★핵심 연결 부분★ ---
  # 1단계에서 만든 공유 리소스의 ID와 ARN을 전달합니다.
  cluster_id                  = aws_ecs_cluster.main.id
  listener_arn                = aws_lb_listener.http.arn
  # --------------------------

  # --- 서비스별 고유 값 전달 ---
  service_name      = each.key
  image_uri         = each.value.image_uri
  container_port    = each.value.container_port
  listener_priority = each.value.priority

  # ... (기타 등등)
}
```
위 코드의 `listener_arn = aws_lb_listener.http.arn` 부분이 바로 "이 리스너에 너희 서비스를 연결해줘" 라는 의미로, 가장 중요한 연결고리 역할을 합니다.

### 3단계: `ecs` 모듈 내부에서의 최종 연결

`application` 레이어로부터 `listener_arn`을 전달받은 `ecs` 모듈은 내부(`terraform/modules/ecs/main.tf`)에서 다음과 같은 리소스를 생성하여 연결을 완성합니다.

#### 📄 `terraform/modules/ecs/main.tf`
```terraform
# 1. 서비스별 타겟 그룹 생성
resource "aws_lb_target_group" "service" {
  name        = "tg-${var.service_name}"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"
  # ... 헬스 체크 등 ...
}

# 2. 서비스별 리스너 규칙 생성 (★최종 연결★)
resource "aws_lb_listener_rule" "service" {
  # 2단계에서 application 레이어로부터 전달받은 리스너 ARN
  listener_arn = var.listener_arn 
  
  priority     = var.listener_priority

  # 동작: 이 규칙에 맞으면, 위에서 만든 타겟 그룹으로 트래픽을 전달
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.service.arn
  }

  # 조건: URL 경로가 /customers-service/* 와 같으면 이 규칙을 적용
  condition {
    path_pattern {
      values = ["/${var.service_name}/*"]
    }
  }
}

# 3. ECS 서비스 생성 및 로드밸런서 연결
resource "aws_ecs_service" "service" {
  # ... (생략) ...
  
  # 이 서비스가 어떤 로드 밸런서와 연결되는지 지정
  load_balancer {
    target_group_arn = aws_lb_target_group.service.arn
    container_name   = var.service_name
    container_port   = var.container_port
  }
}
```
`aws_lb_listener_rule` 리소스가 `application` 레이어에서 받은 `listener_arn`을 사용하여, "`/서비스이름/*` 경로의 요청은 이 서비스의 타겟 그룹으로 보내라"는 안내 표지판을 ALB에 설치하는 역할을 합니다.

---

## 결론

현재 우리 프로젝트는 다음과 같이 체계적으로 역할이 분리되어 동작합니다.

1.  **`application` 레이어**가 **ALB와 리스너**라는 '공용 버스 정류장'을 만듭니다.
2.  `application` 레이어가 각 **`ecs` 모듈**에게 "너희 서비스는 이 버스 정류장을 사용해" 라고 **정류장 주소(`listener_arn`)**를 알려주며 호출합니다.
3.  각 **`ecs` 모듈**은 정류장 주소를 받아서 "`/customers-service` 행 버스는 우리 쪽으로 와야 합니다" 라는 **안내 표지판(`aws_lb_listener_rule`)**을 정류장에 설치합니다.

이 구조 덕분에 새로운 서비스를 추가할 때 `ecs.tf`의 `locals` 블록에 서비스 정보 몇 줄만 추가하면 모든 연결이 자동으로 구성되는 매우 확장성 높은 구조가 완성되었습니다.
