# Terraform ECS와 SSM Parameter Store 연동 가이드

이 문서는 `ecs.tf`에 하드코딩된 `container_port` 같은 변수를 AWS SSM Parameter Store에서 동적으로 가져오도록 리팩토링하는 과정을 기록한 가이드입니다.

## 1. 목표

`ecs.tf`의 `locals` 블록에 하드코딩된 `container_port = 8080` 값을 제거하고, 각 서비스에 해당하는 Parameter Store의 파라미터 값을 읽어와 동적으로 설정하는 것을 목표로 합니다.

- **Parameter Store 경로 형식:** `/petclinic/dev/{서비스 경로 이름}.port` (예: `/petclinic/dev/admin/server.port`)

---

## 2. 핵심 해결 과제

#### 문제점
각 서비스마다 다른 파라미터 경로를 사용해야 하므로, `for_each`를 사용해 여러 파라미터를 동시에 조회해야 합니다. 하지만 `locals` 변수를 정의하면서 동시에 해당 변수를 참조하여 `for_each`를 사용하면 Terraform에서 '순환 종속성(Circular Dependency)' 오류가 발생할 수 있습니다.

#### 해결책
`locals` 블록을 2단계로 분리하고 `data` 소스를 중간에 두어 종속성 문제를 해결합니다.
1.  **1단계 (정적 데이터 정의):** 서비스별 고유 설정(우선순위, 파라미터 경로 이름 등)을 `locals`로 먼저 정의합니다.
2.  **2단계 (데이터 조회):** 1단계에서 정의한 `locals`를 참조하여 `data` 블록에서 `for_each`로 Parameter Store 값을 모두 가져옵니다.
3.  **3단계 (동적 조합):** 1, 2단계의 모든 정보를 조합하여 최종 `ecs_services` 맵을 `for` 표현식을 사용해 동적으로 생성합니다.

---

## 3. `ecs.tf` 최종 수정 코드

아래 코드는 위 해결책을 적용하여 `ecs.tf`의 기존 `locals` 블록을 대체한 최종 버전입니다.

```terraform
# terraform/envs/dev/application/ecs.tf

locals {
  # 1. 서비스별 고유 설정과 "파라미터 스토어 경로에 사용할 이름"을 함께 정의합니다.
  #    - Terraform 내부에서 사용하는 서비스 이름(맵의 키)과
  #    - Parameter Store 경로에 실제 사용할 이름(path_name)을 분리하여 유연성을 확보합니다.
  service_definitions = {
    "customers-service" = { priority = 100, path_name = "customers-service" }
    "vets-service"      = { priority = 110, path_name = "vets-service" }
    "visits-service"    = { priority = 120, path_name = "visits-service" }
    # admin-server의 경우, 논의된 형식에 맞춰 "admin/server"로 지정합니다.
    "admin-server"      = { priority = 130, path_name = "admin/server" }
  }
}

# 2. for_each를 사용해 각 서비스의 포트 번호를 Parameter Store에서 가져옵니다.
#    새로 추가한 path_name을 사용해 경로를 동적으로 구성합니다.
data "aws_ssm_parameter" "service_ports" {
  for_each = local.service_definitions
  name     = "/petclinic/dev/${each.value.path_name}.port"
}

# 3. 위 정보들을 조합하여 ecs_services 맵을 동적으로 생성합니다.
locals {
  ecs_services = {
    for name, config in local.service_definitions : name => {
      # 데이터 소스는 원래 서비스 이름(map의 key)으로 참조합니다.
      container_port = tonumber(data.aws_ssm_parameter.service_ports[name].value)
      image_uri      = "${module.ecr.repository_urls[name]}:latest"
      priority       = config.priority
    }
  }
}
```

---

## 4. 주요 Q&A

#### Q: `each.key`는 어디서 참조해오나요? Parameter Store의 이름과 다를 수 있지 않나요?
**A:** 훌륭한 질문입니다. `each.key`는 `for_each`가 반복하는 맵의 '키'(`"vets-service"` 등)를 가리킵니다. 만약 이 이름이 Parameter Store 경로의 형식과 다르다면 문제가 될 수 있습니다.

위 최종 코드에서는 이 문제를 해결하기 위해 `service_definitions` 맵 안에 `path_name`이라는 별도 필드를 만들었습니다.

- **`each.key`**: `"vets-service"` (Terraform 내부에서 리소스를 식별하는 용도)
- **`each.value.path_name`**: `"vets-service"` 또는 `"admin/server"` (실제 파라미터 경로를 구성하는 용도)

이렇게 두 이름을 분리함으로써, Terraform 코드의 일관성을 유지하면서 외부 서비스(Parameter Store)의 명명 규칙을 유연하게 따를 수 있습니다.
