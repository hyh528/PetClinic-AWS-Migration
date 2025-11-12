# ECS Task 정상 작동 해결 과정 요약

이 문서는 Spring PetClinic 마이크로서비스의 `customers-service` ECS 태스크가 AWS Parameter Store 및 Secrets Manager에서 설정을 로드하지 못하고 시작에 실패했던 문제를 해결하는 과정을 상세히 기록합니다.

## 1. 문제 개요

`customers-service` 애플리케이션이 ECS Fargate 태스크로 배포되었을 때, `application.yml`에 정의된 `spring.config.import`를 통해 AWS Parameter Store 및 Secrets Manager에서 설정값을 가져오는 과정에서 오류가 발생하여 애플리케이션이 시작되지 못했습니다.

## 2. 문제 해결 과정 (단계별 진단 및 해결)

### 2.1. 1차 문제: `application.yml`의 Secrets Manager 경로 오류

**오류 메시지 (초기):**
```
Config data resource ... 'aws-secretsmanager:///petclinic/common/database-secret-arn' does not exist
```

**원인 진단:**
`customers-service`의 `application.yml`에 Secrets Manager에서 DB 비밀번호를 가져오는 경로가 잘못 지정되어 있었습니다. 또한, Parameter Store에서 서비스별 설정(`customers-service` 전용)을 가져오는 경로도 누락되어 있었습니다.

**해결:**
`customers-service/src/main/resources/application.yml` 파일의 `spring.config.import` 블록을 아래와 같이 수정하여 올바른 Secrets Manager 경로와 누락된 Parameter Store 경로를 추가했습니다.

**수정된 `application.yml` `import` 블록:**
```yaml
spring:
  application:
    name: customers-service
  config:
    import: [
      "aws-parameterstore:/petclinic/common/",
      "aws-parameterstore:/petclinic/dev/customers/",
      "aws-secretsmanager:/rdslcluster-bfbb6ec3-3428-4242-a86c-c80fc933791c" # 실제 RDS 시크릿 이름
    ]
  cloud:
    aws:
      region:
        static: ${AWS_REGION:ap-northeast-2}
```

### 2.2. 2차 문제: Parameter Store 접근 IAM 권한 오류

**오류 메시지 (1차 수정 후):**
```
Config data resource ... 'aws-parameterstore:/petclinic/dev/customers' does not exist
```

**원인 진단:**
`application.yml` 수정 후에도 동일한 오류가 발생했습니다. 파라미터(`/petclinic/dev/customers/server.port`)는 Parameter Store에 존재함을 확인했으므로, 문제는 ECS 태스크가 해당 파라미터를 읽을 IAM 권한이 없기 때문으로 진단했습니다.

**해결:**
ECS 태스크가 Parameter Store 및 Secrets Manager에 접근할 수 있도록 IAM 정책과 VPC 엔드포인트 정책을 수정했습니다.

1.  **IAM 역할 정책 (`petclinic-ecs-secrets-policy-v2`) 수정:**
    -   ECS 태스크 역할(`petclinic-ecs-task-execution-role-v2`)에 연결된 정책에 `ssm:GetParametersByPath` 액션을 추가했습니다.
    -   **권장 정책 (최소 권한 원칙):**
        ```json
        {
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Sid": "AllowAccessToPetClinicParameters",
                    "Effect": "Allow",
                    "Action": [
                        "ssm:GetParameters",
                        "ssm:GetParameter",
                        "ssm:GetParametersByPath"
                    ],
                    "Resource": [
                        "arn:aws:ssm:ap-northeast-2:ACCOUNT_ID:parameter/petclinic/common/*",
                        "arn:aws:ssm:ap-northeast-2:ACCOUNT_ID:parameter/petclinic/dev/customers/*"
                    ]
                },
                {
                    "Sid": "AllowAccessToDBSecret",
                    "Effect": "Allow",
                    "Action": "secretsmanager:GetSecretValue",
                    "Resource": "arn:aws:secretsmanager:ap-northeast-2:ACCOUNT_ID:secret:rdslcluster-bfbb6ec3-3428-4242-a86c-c80fc933791c-XXXXXX"
                },
                {
                    "Sid": "AllowKMSDecryptForDBSecret",
                    "Effect": "Allow",
                    "Action": "kms:Decrypt",
                    "Resource": "arn:aws:kms:ap-northeast-2:ACCOUNT_ID:key/KMS_KEY_ID_OF_THE_SECRET"
                }
            ]
        }
        ```
        *(참고: `ACCOUNT_ID`, RDS 시크릿 ARN의 `XXXXXX` 부분, KMS 키 ID는 실제 값으로 대체해야 합니다.)*

2.  **VPC 엔드포인트 정책 (`petclinic-ssm-vpce`) 수정:**
    -   SSM VPC 엔드포인트 정책에 `ssm:GetParametersByPath` 액션을 추가했습니다.
    -   **수정된 VPC 엔드포인트 정책:**
        ```json
        {
            "Statement": [
                {
                    "Action": [
                        "ssm:GetParameters",
                        "ssm:GetParameter",
                        "ssm:DescribeParameters",
                        "ssm:GetParametersByPath"
                    ],
                    "Effect": "Allow",
                    "Principal": "*",
                    "Resource": "*"
                }
            ],
            "Version": "2012-10-17"
        }
        ```

### 2.3. 3차 문제: `spring.profiles.active` 설정 위치 오류

**오류 메시지 (2차 수정 후):**
```
Property 'spring.profiles.active' imported from location ... is invalid in a profile specific resource
```

**원인 진단:**
Spring Boot는 `spring.profiles.active` 속성을 원격 설정 소스(`spring.config.import`로 가져온 Parameter Store)에서 설정하는 것을 허용하지 않습니다. 이 속성은 애플리케이션 시작 시점에 가장 먼저 결정되어야 하는 '환경 결정' 정보이기 때문입니다.

**해결:**
1.  **Parameter Store에서 `spring.profiles.active` 파라미터 삭제:**
    -   `/petclinic/common/spring.profiles.active` 파라미터를 AWS SSM Parameter Store에서 삭제했습니다.
2.  **ECS 태스크 정의에 환경 변수 추가 (Terraform으로 관리):**
    -   `SPRING_PROFILES_ACTIVE` 환경 변수를 ECS 태스크 정의에 추가하여 애플리케이션 시작 시점에 프로파일 정보를 전달하도록 했습니다.

    **Terraform 코드 수정:**

    **a. `terraform/modules/ecs/variables.tf` 수정:**
    ```terraform
    # 기존 변수들 아래에 추가
    variable "environment_variables" {
      description = "A map of environment variables to pass to the container."
      type        = map(string)
      default     = {}
    }
    ```

    **b. `terraform/modules/ecs/main.tf` 수정:**
    `aws_ecs_task_definition` 리소스의 `container_definitions` 안에 `environment` 블록을 추가합니다.
    ```terraform
      container_definitions = jsonencode([
        {
          name      = var.service_name,
          image     = var.image_uri,
          # ... (기존 내용) ...
          # 이 부분이 추가됩니다.
          environment = [
            for k, v in var.environment_variables : {
              name  = k,
              value = v
            }
          ],
          secrets = [ # ... (기존 내용) ... ],
          logConfiguration = { # ... (기존 내용) ... }
        }
      ])
    ```

    **c. `terraform/envs/dev/application/ecs.tf` 수정:**
    `module "ecs"` 블록 안에 `environment_variables` 파라미터를 추가합니다.
    ```terraform
    module "ecs" {
      for_each = local.ecs_services
      source   = "../../../modules/ecs"

      # ... (기존 파라미터들) ...
      
      # 이 부분이 추가됩니다.
      environment_variables = {
        "SPRING_PROFILES_ACTIVE" = "mysql,aws"
      }

      # ... (기존 나머지 파라미터들) ...
    }
    ```

### 2.4. Terraform 모듈 캐시 문제 해결

**오류 메시지 (Terraform apply 중):**
```
Error: Unsupported argument ... An argument named "environment_variables" is not expected here.
```

**원인 진단:**
`ecs` 모듈에 `environment_variables` 변수를 추가했음에도 불구하고, `terraform apply` 시 모듈이 해당 변수를 인식하지 못했습니다. 이는 Terraform이 로컬 모듈의 변경 사항을 즉시 반영하지 않고 `.terraform` 디렉터리의 캐시된 버전을 사용했기 때문입니다.

**해결:**
`terraform/envs/dev/application` 디렉터리에서 `terraform init` 명령어를 다시 실행하여 Terraform 모듈 캐시를 새로고침했습니다.

## 3. 최종 결과

위의 모든 문제 해결 과정을 거쳐 `customers-service` ECS 태스크가 AWS Parameter Store 및 Secrets Manager에서 필요한 설정값을 성공적으로 로드하고 정상 작동하게 되었습니다.

---

**핵심 교훈:**

*   **IAM 권한은 최소 권한 원칙:** `Resource: "*"`나 `Action: "*"`는 편리하지만 보안상 매우 위험합니다. 필요한 리소스와 액션만 명시해야 합니다.
*   **Spring Boot 설정 로딩 순서 이해:** `spring.profiles.active`와 같은 핵심 설정은 특정 위치(환경 변수, 로컬 `application.yml`)에서만 유효합니다.
*   **Terraform 모듈 캐시:** 로컬 모듈을 수정한 후에는 `terraform init`을 다시 실행하여 변경 사항을 반영해야 할 수 있습니다.
