# Eureka에서 AWS Cloud Map으로 전환 가이드

이 문서는 기존 Eureka 기반의 서비스 디스커버리를 AWS Cloud Map으로 전환하는 과정을 정리한 가이드입니다.

## 기본 개념

- **Eureka Server 불필요:** AWS Cloud Map은 AWS에서 직접 관리해주는 서비스(Managed Service)이므로, 기존처럼 `discovery-server` 애플리케이션을 직접 띄울 필요가 없습니다.
- **전환 방식:** 각 마이크로서비스가 Eureka에 등록하는 대신, AWS Cloud Map에 직접 자신을 등록하도록 코드와 설정을 변경합니다.

---

## 1단계: Terraform으로 Cloud Map 인프라 구축

Terraform을 사용하여 모든 마이크로서비스가 등록될 중앙 "주소록"인 Cloud Map Namespace를 생성합니다.

#### 1. Cloud Map 모듈 확인 (`terraform/modules/cloudmap/`)

아래와 같이 Private DNS Namespace와 그 안의 서비스들을 생성하는 모듈이 준비되어 있습니다.

<details>
<summary>📄 `main.tf`</summary>

```terraform
resource "aws_service_discovery_private_dns_namespace" "this" {
  name        = var.namespace_name
  description = "Petclinic 마이크로서비스용 Private DNS 네임스페이스"
  vpc         = var.vpc_id
}

resource "aws_service_discovery_service" "this" {
  for_each = var.service_name_map

  name        = each.key
  description = each.value

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.this.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}
```
</details>

#### 2. `dev` 환경에서 Cloud Map 모듈 사용

`network` 레이어에서 위 모듈을 사용하여 실제 Cloud Map 리소스를 생성합니다.

**파일 경로:** `terraform/envs/dev/network/cloudmap.tf`

```terraform
module "cloudmap" {
  source = "../../../modules/cloudmap"

  # 'network' 디렉토리의 main.tf에 정의된 vpc 모듈을 참조
  vpc_id         = module.vpc.vpc_id
  
  # VPC 내부에서 사용할 DNS 이름 (예: customers-service.petclinic.local)
  namespace_name = "petclinic.local"

  # Cloud Map에 등록할 마이크로서비스 목록
  service_name_map = {
    "api-gateway"       = "API Gateway"
    "customers-service" = "Customers Service"
    "vets-service"      = "Vets Service"
    "visits-service"    = "Visits Service"
    "genai-service"     = "GenAI Service"
  }
}
```

---

## 2단계: 마이크로서비스 코드 수정

`customers-service`, `api-gateway` 등 각 마이크로서비스의 코드와 설정을 변경합니다.

#### 1. 의존성(pom.xml) 수정

**A. 최상위 `pom.xml`에 버전 관리 추가 (최초 1회)**

프로젝트 전체의 AWS 의존성 버전을 관리하기 위해 `<dependencyManagement>` 섹션에 `spring-cloud-aws-dependencies`를 추가합니다.

```xml
            <dependency>
                <groupId>io.awspring.cloud</groupId>
                <artifactId>spring-cloud-aws-dependencies</artifactId>
                <version>3.1.1</version>
                <type>pom</type>
                <scope>import</scope>
            </dependency>
```

**B. 각 서비스의 `pom.xml` 수정**

기존 Eureka 클라이언트 의존성을 찾아서 AWS Service Discovery 의존성으로 교체합니다.

- **변경 전:**
  ```xml
          <dependency>
              <groupId>org.springframework.cloud</groupId>
              <artifactId>spring-cloud-starter-netflix-eureka-client</artifactId>
          </dependency>
  ```

- **변경 후:**
  ```xml
          <dependency>
              <groupId>io.awspring.cloud</groupId>
              <artifactId>spring-cloud-starter-aws-servicediscovery</artifactId>
          </dependency>
  ```

#### 2. 설정(`config/*.yml`) 수정

중앙 설정 파일이 모여있는 `config/` 디렉토리에서 각 서비스의 `.yml` 파일을 수정합니다.

- **변경 전 (`customers-service.yml` 예시):**
  ```yaml
  eureka:
    client:
      serviceUrl:
        defaultZone: http://discovery-server:8761/eureka/
  ```

- **변경 후 (`customers-service.yml` 예시):**
  ```yaml
  spring:
    # ... 기존 datasource 등 설정 ...
    cloud:
      aws:
        region:
          static: ap-northeast-2
        servicediscovery:
          enabled: true
          namespace: petclinic.local
  eureka:
    client:
      enabled: false
  ```

- **API Gateway의 경우 추가 설정 (`api-gateway.yml`):**
  API Gateway가 Cloud Map으로 다른 서비스를 찾으려면 아래 설정이 추가로 필요합니다.
  ```yaml
  spring:
    cloud:
      gateway:
        discovery:
          locator:
            enabled: true
            lower-case-service-id: true 
  ```

---

## 3단계: 모든 서비스에 반복 적용

위 2단계의 (`pom.xml`, `*.yml` 수정) 작업을 아래 서비스에 모두 반복합니다.

- `api-gateway`
- `customers-service`
- `vets-service`
- `visits-service`
- `genai-service`

모든 서비스 전환이 완료되면, 더 이상 필요 없는 `spring-petclinic-discovery-server` 모듈은 프로젝트에서 완전히 삭제할 수 있습니다.
