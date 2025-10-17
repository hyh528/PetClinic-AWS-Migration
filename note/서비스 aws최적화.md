# 마이크로서비스 AWS 최적화 전환 기록

이 문서는 기존 Spring Cloud 기반의 마이크로서비스 아키텍처를 AWS의 관리형 서비스(Managed Service)로 전환하는 전체 과정을 상세하게 기록한 문서입니다.

## 1. 최종 목표

- **서비스 디스커버리:** `Eureka Server`를 `AWS Cloud Map`으로 전환합니다.
- **API 게이트웨이:** `Spring Cloud Gateway`를 `AWS API Gateway`로 전환합니다.
- **설정 관리:** `Spring Cloud Config Server`를 `AWS Systems Manager Parameter Store`로 전환합니다. (개념만 포함)

---

## 2. Terraform을 이용한 인프라 변경

애플리케이션 배포에 앞서 필요한 AWS 인프라를 Terraform 코드로 정의하고 수정했습니다.

### 2.1. ECR 리포지토리 수정 (`ecr.tf`)
- **목표:** `api-gateway`는 더 이상 컨테이너로 배포하지 않으므로 ECR 목록에서 제외하고, `admin-server`를 추가합니다.
- **수정 내용:** `repository_names` 목록 수정

```terraform
# terraform/envs/dev/application/ecr.tf
module "ecr" {
  source = "../../../modules/ecr"

  repository_names = [
    "customers-service",
    "vets-service",
    "visits-service",
    "admin-server" # admin-server 추가
  ]
  # ...
} 
```

### 2.2. Cloud Map 서비스 등록 (`cloudmap.tf`)
- **목표:** `admin-server`를 포함한 모든 서비스가 Cloud Map을 통해 서로를 찾을 수 있도록 등록합니다.
- **수정 내용:** `service_name_map`에 `admin-server` 추가

```terraform
# terraform/envs/dev/application/cloudmap.tf
module "cloudmap" {
  # ...
  service_name_map = {
    "customers-service" = "customer service"
    "vets-service"      = "vets-service"
    "visits-service"    = "visits-service"
    "admin-server"      = "admin-server"
  }
}
```

### 2.3. ECS 서비스 배포 정의 (`ecs.tf`)
- **목표:** `admin-server`를 ECS 컨테이너로 배포하도록 정의합니다.
- **수정 내용:** `locals.ecs_services` 맵에 `admin-server` 항목 추가

```terraform
# terraform/envs/dev/application/ecs.tf
locals {
  ecs_services = {
    # ... 기존 서비스 ...
    "admin-server" = {
      container_port = 8080
      image_uri      = "${module.ecr.repository_urls["admin-server"]}:latest"
      priority       = 130
    }
  }
}
```

### 2.4. AWS API Gateway 생성 (`api-gateway.tf`)
- **목표:** Spring Cloud Gateway를 대체할 AWS 관리형 API Gateway를 생성합니다.
- **수정 내용:** `api-gateway.tf` 파일 신규 생성

```terraform
# terraform/envs/dev/application/api-gateway.tf
module "api_gateway" {
  source = "../../../modules/api-gateway"

  project_name = "petclinic"
  environment  = "dev"
  alb_dns_name = aws_lb.main.dns_name
}
```

### 2.5. 출력 변수 정의 (`outputs.tf`)
- **목표:** 배포 후 생성된 API Gateway의 URL을 쉽게 확인하기 위해 출력 변수를 정의합니다.
- **수정 내용:** `outputs.tf` 파일 신규 생성

```terraform
# terraform/envs/dev/application/outputs.tf
output "api_gateway_invoke_url" {
  description = "The invoke URL for the API Gateway stage"
  value       = module.api_gateway.invoke_url
}
```

---

## 3. 애플리케이션 코드 변경 (`admin-server` 예시)

Eureka 클라이언트를 AWS Cloud Map 클라이언트로 전환하는 과정입니다. 이 과정은 `customers-service` 등 다른 모든 서비스에 동일하게 적용되어야 합니다.

### 3.1. `pom.xml` 의존성 변경
- **제거:** `spring-cloud-starter-netflix-eureka-client`
- **추가:** `spring-cloud-aws-starter-servicediscovery`

```xml
<!-- 변경 전 -->
<dependency>
    <groupId>org.springframework.cloud</groupId>
    <artifactId>spring-cloud-starter-netflix-eureka-client</artifactId>
</dependency>

<!-- 변경 후 -->
<dependency>
    <groupId>io.awspring.cloud</groupId>
    <artifactId>spring-cloud-aws-starter-servicediscovery</artifactId>
</dependency>
```

### 3.2. `application.yml` 설정 변경
- **목표:** Spring Boot Admin 서버가 Cloud Map을 통해 다른 서비스들을 찾도록 설정을 추가합니다.

```yaml
# 변경 후
spring:
  application:
    name: admin-server
  config:
    import: optional:configserver:${CONFIG_SERVER_URL:http://localhost:8888/}
  boot:
    admin:
      server:
        instance-discovery:
          use-discovery-client: true # Discovery Client를 사용해 인스턴스를 찾도록 설정
```

---

## 4. 주요 Q&A 및 개념 정리

#### Q: Terraform으로 ECR에 이미지를 넣을 수 있나요?
**A:** 아니요. Terraform은 ECR 리포지토리(빈 저장소) 같은 **인프라**를 생성하는 역할입니다. Docker 이미지를 빌드하고 푸시하는 것은 `docker` 명령어 또는 `scripts/pushImages.sh` 같은 **CI/CD/빌드 스크립트**의 역할입니다. 역할이 명확하게 분리되어 있습니다.

#### Q: ECS Task CPU "256"은 0.25vCPU가 맞나요?
**A:** 네, 맞습니다. AWS Fargate에서는 **1 vCPU = 1024 CPU 유닛**으로 계산합니다. 따라서 `256`은 `0.25 vCPU`를 의미하며, 마이크로서비스에 대한 세밀한 리소스 할당이 가능합니다.

#### Q: Config Server를 Parameter Store로 바꾸려면 어떻게 해야 하나요?
**A:** 두 가지 수정이 필요합니다.
1.  **`pom.xml` 수정:** `spring-cloud-starter-config` 의존성을 제거하고, `spring-cloud-aws-starter-parameter-store` 의존성을 추가합니다.
2.  **`bootstrap.yml` 수정:** `spring.config.import: configserver:...` 라인을 제거하고, `spring.config.import: "aws-parameterstore:/config/admin-server/"` 와 같이 Parameter Store의 경로를 지정하는 라인을 추가합니다.

---

## 5. 최종 실행 계획 (To-Do List)

1.  **Terraform으로 인프라 배포:** `terraform/envs/dev/application` 경로에서 `terraform apply`를 실행하여 위에서 정의한 AWS 인프라를 생성합니다.
2.  **나머지 서비스 코드 수정:** `customers-service`, `vets-service`, `visits-service`의 `pom.xml`을 `admin-server`와 동일하게 수정합니다.
3.  **모든 서비스 빌드:** 코드를 수정한 모든 서비스를 각 프로젝트 폴더에서 `mvnw.cmd clean package` 명령어로 빌드합니다.
4.  **Docker 이미지 푸시:** 빌드된 `.jar` 파일로 Docker 이미지를 만들고, `scripts/pushImages.sh` 등을 이용해 ECR에 푸시합니다.
5.  **ECS 서비스 업데이트:** AWS 콘솔에서 각 ECS 서비스의 '새 배포 강제'를 실행하여 ECR에 올라간 새 이미지를 적용합니다.
6.  **최종 확인:** `terraform apply` 후 출력된 `api_gateway_invoke_url`로 API를 호출하고, `admin-server`에서 모든 서비스가 정상적으로 보이는지 확인합니다.