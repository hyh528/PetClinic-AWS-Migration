# Eureka -> AWS Cloud Map 전환 상세 과정 기록

이 문서는 Spring PetClinic 마이크로서비스의 서비스 디스커버리를 Eureka에서 AWS Cloud Map으로 전환하는 전체 과정을 코드, 설명, 질문/답변을 포함하여 상세하게 기록한 문서입니다.

## 1. 기본 개념 및 목표

- **기본 개념:** AWS Cloud Map은 AWS에서 직접 관리하는 서비스이므로, 기존처럼 `discovery-server` 애플리케이션을 직접 실행할 필요가 없습니다.
- **목표:** 각 마이크로서비스(`customers-service`, `api-gateway` 등)가 Eureka 서버 대신 AWS Cloud Map에 자신을 등록하고, 다른 서비스를 찾을 수 있도록 수정합니다.

---

## 2. Terraform 인프라 구축

애플리케이션 코드를 수정하기 전에, 서비스들이 등록될 AWS Cloud Map 리소스를 Terraform으로 먼저 생성합니다.

### 2.1. Cloud Map 모듈 확인

`terraform/modules/cloudmap/` 디렉토리의 `main.tf`에 Private DNS Namespace와 Service를 생성하는 코드가 이미 준비되어 있었습니다.

```terraform
# terraform/modules/cloudmap/main.tf

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

### 2.2. `dev` 환경에서 모듈 사용

`dev` 환경의 `network` 레이어에서 위 모듈을 사용하도록 `cloudmap.tf` 파일을 추가했습니다.

> **Q: 왜 `application`이 아닌 `network` 디렉토리에 만들어야 하나요?**
> **A:** Cloud Map은 서비스 간의 통신(네트워킹)을 담당하는 핵심 기반 인프라이며, VPC에 강하게 종속되어 있기 때문입니다. `network` 디렉토리는 VPC, 서브넷 등 네트워킹의 기반을 관리하는 곳이므로 이곳에 함께 두는 것이 논리적으로 가장 적합합니다. `application` 디렉토리는 이렇게 만들어진 기반 위에 실제 애플리케이션(ECS, ALB 등)을 배포하는 역할을 합니다.

**파일 경로:** `terraform/envs/dev/network/cloudmap.tf`

```terraform
module "cloudmap" {
  source = "../../../modules/cloudmap"

  vpc_id         = module.vpc.vpc_id
  namespace_name = "petclinic.local"

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

## 3. 마이크로서비스 코드 수정

Terraform 인프라가 준비되었다고 가정하고, 각 마이크로서비스의 `pom.xml`과 `config/*.yml` 파일을 수정했습니다.

### 3.1. `pom.xml` 의존성 수정

#### A. 최상위 `pom.xml` : 버전 관리 추가 (최초 1회)

모든 하위 모듈의 AWS 의존성 버전을 중앙에서 관리하기 위해, 프로젝트 최상위 `pom.xml`의 `<dependencyManagement>` 섹션에 `spring-cloud-aws-dependencies`를 추가했습니다.

```xml
<!-- 최상위 pom.xml -->
<dependencyManagement>
    <dependencies>
        <!-- ... 기존 의존성 ... -->
        <dependency>
            <groupId>io.awspring.cloud</groupId>
            <artifactId>spring-cloud-aws-dependencies</artifactId>
            <version>3.1.1</version>
            <type>pom</type>
            <scope>import</scope>
        </dependency>
    </dependencies>
</dependencyManagement>
```

#### B. 각 서비스 `pom.xml`: Eureka 의존성 교체

`api-gateway`, `customers-service`, `vets-service`, `visits-service`, `genai-service` 각각의 `pom.xml`에서 아래와 같이 의존성을 교체했습니다.

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

### 3.2. `config/*.yml` 설정 수정

중앙 설정 파일이 모여있는 `config/` 디렉토리에서 각 서비스의 `.yml` 파일을 수정했습니다.

- **`customers-service`, `vets-service`, `visits-service` 수정 내용:**
  ```yaml
  # 변경 전 (예시)
  eureka:
    client:
      serviceUrl:
        defaultZone: http://discovery-server:8761/eureka/
  ```
  ```yaml
  # 변경 후 (예시)
  spring:
    # ... datasource 등 기존 설정 ...
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

- **`api-gateway.yml` 수정 내용:**
  API Gateway는 다른 서비스를 찾아야 하므로 `spring.cloud.gateway.discovery.locator` 설정을 추가했습니다.
  ```yaml
  # 변경 후
  spring:
    cloud:
      gateway:
        discovery:
          locator:
            enabled: true
            lower-case-service-id: true
      aws:
        # ... aws 설정 ...
  ```

- **`genai-service.yml` 수정 내용:**
  Datasource가 없는 서비스도 동일하게 Cloud Map 설정을 추가했습니다.

> **참고: Parameter Store / Secrets Manager로의 전환**
> 추후 이 설정들은 `.yml` 파일이 아닌 AWS Parameter Store나 Secrets Manager로 이전할 수 있습니다. `spring-cloud-aws-starter-parameter-store-config` 의존성을 추가하고 `bootstrap.yml`에 `spring.config.import: "aws-parameterstore:/..."`와 같이 설정하면, 애플리케이션이 시작될 때 AWS에서 직접 설정값을 읽어오게 됩니다. 이는 더 안전하고 유연한 방법입니다.

---

## 4. 최종 확인 및 정리

### 4.1. 전체 파일 점검

모든 대상 서비스(`api-gateway`, `customers-service`, `vets-service`, `visits-service`, `genai-service`)의 `pom.xml`과 `config/*.yml` 파일이 올바르게 수정되었는지 최종적으로 모두 확인했습니다.

### 4.2. Discovery Server 비활성화

모든 전환이 완료되었으므로, 더 이상 필요 없는 `discovery-server` 모듈을 빌드에서 제외하기 위해 최상위 `pom.xml`에서 해당 모듈을 주석 처리했습니다.

> **Q: 삭제하는 대신 주석 처리해도 되나요?**
> **A:** 네, 더 좋은 방법입니다. 코드를 바로 삭제하기보다 주석으로 남겨두면 나중에 다시 필요할 때 쉽게 복구할 수 있어 더 안전합니다.

```xml
<!-- 최상위 pom.xml -->
<modules>
    <!-- ... 다른 모듈들 ... -->
    <!-- <module>spring-petclinic-discovery-server</module> -->
    <module>spring-petclinic-api-gateway</module>
</modules>
```

이것으로 Eureka에서 AWS Cloud Map으로의 서비스 디스커버리 전환 작업이 성공적으로 완료되었습니다.
