# To-Be RDS 및 설정 관리 방안 제안서

## 1. 서론

안녕하세요, 박준제입니다. PetClinic 마이크로서비스 아키텍처의 AWS 마이그레이션 프로젝트를 위한 데이터베이스 및 설정 관리 방안을 제안합니다. 본 제안서는 마이크로서비스의 핵심 원칙인 '서비스별 데이터베이스(Database-per-Service)' 패턴을 준수하고, 기존 Config Server를 AWS Parameter Store로 대체하는 방안을 중점적으로 다룹니다. 운영 효율성, 비용, 보안, 고가용성 측면을 종합적으로 고려하여 최적의 아키텍처를 구축하는 것을 목표로 합니다.

## 2. 서비스별 RDS 인스턴스 구성 방안 (논리적 DB 분리)

### 2.1. 제안 배경 및 목표

마이크로서비스 아키텍처의 '서비스별 데이터베이스' 패턴을 준수하여 각 서비스가 독립적인 데이터베이스를 소유하도록 구성합니다. 이는 '아파트 단지' 모델과 유사하게, 각 서비스가 자신의 데이터베이스 스키마와 데이터를 독립적으로 관리하며, 다른 서비스에 영향을 주지 않고 변경 및 배포가 가능하도록 합니다. 이를 통해 서비스 간의 느슨한 결합을 보장하고, 명확한 데이터 소유권을 확립하여 MSA 사상에 부합하는 아키텍처를 구축합니다.

### 2.2. 장점 (재강조)

*   **독립성 보장 (느슨한 결합):** 각 서비스는 자신의 데이터베이스 스키마와 데이터를 독립적으로 관리하므로, 특정 서비스의 변경이 다른 서비스에 미치는 영향을 최소화합니다. 이는 개발 및 배포 속도 향상에 기여합니다.
*   **명확한 소유권:** 각 데이터는 담당 서비스가 명확하게 소유하고 책임지므로, 데이터 관리 및 문제 해결이 용이합니다.
*   **MSA 사상 부합:** 마이크로서비스 아키텍처의 핵심 철학에 가장 잘 맞는 이상적인 구조로, 서비스의 자율성을 극대화합니다.

### 2.3. 고려 사항

#### 2.3.1. 운영 효율성 (Operational Excellence)

*   **모니터링 및 관리:** 각 RDS 인스턴스에 대한 개별적인 모니터링 및 관리가 필요합니다. AWS CloudWatch, RDS Performance Insights 등을 활용하여 각 인스턴스의 성능 및 상태를 효과적으로 추적해야 합니다.
*   **자동화:** RDS 인스턴스 생성, 백업, 패치 등의 작업을 AWS CloudFormation, Terraform과 같은 IaC(Infrastructure as Code) 도구를 사용하여 자동화하여 운영 부담을 줄입니다.
*   **장애 격리:** 서비스별 DB 분리는 한 서비스의 DB 장애가 다른 서비스로 전파되는 것을 방지하여 전체 시스템의 안정성을 높입니다.

#### 2.3.2. 비용 (Cost)

*   **인스턴스 비용:** 서비스별로 RDS 인스턴스를 생성하므로, 통합 DB 대비 인스턴스 수가 증가하여 기본 비용이 상승할 수 있습니다. 하지만 각 서비스의 트래픽 및 데이터 요구사항에 맞춰 인스턴스 타입을 최적화하여 불필요한 비용 지출을 줄일 수 있습니다.
*   **스토리지 및 I/O 비용:** 각 인스턴스의 스토리지 및 I/O 사용량에 따라 비용이 발생합니다. 필요한 만큼만 할당하고, Auto Scaling 기능을 활용하여 유연하게 관리합니다.
*   **비용 최적화:** AWS Reserved Instances 또는 Savings Plans를 활용하여 장기적인 비용 절감을 고려할 수 있습니다.

#### 2.3.3. 보안 (Security)

*   **접근 제어:** 각 RDS 인스턴스에 대해 최소 권한 원칙(Least Privilege)을 적용하여 접근 제어를 강화합니다. AWS IAM을 통해 서비스별로 필요한 권한만 부여하고, Security Group을 사용하여 네트워크 접근을 제한합니다.
*   **데이터 암호화:** 저장 데이터(Encryption at Rest) 및 전송 중 데이터(Encryption in Transit) 모두 암호화를 적용합니다. AWS KMS(Key Management Service)를 활용하여 암호화 키를 관리합니다.
*   **취약점 관리:** 정기적인 보안 패치 및 취약점 점검을 수행하여 보안 위협에 대비합니다.

#### 2.3.4. 고가용성 (Availability)

*   **Multi-AZ 배포:** 각 RDS 인스턴스를 Multi-AZ(Multi-Availability Zone)로 배포하여 자동화된 장애 조치(Failover)를 통해 고가용성을 확보합니다. 이는 한 AZ에 장애가 발생하더라도 서비스 중단 없이 운영될 수 있도록 합니다.
*   **읽기 전용 복제본 (Read Replicas):** 읽기 트래픽이 많은 서비스의 경우, 읽기 전용 복제본을 사용하여 데이터베이스 부하를 분산하고 읽기 성능을 향상시킬 수 있습니다.
*   **백업 및 복구:** 자동 백업 및 특정 시점 복구(Point-in-Time Recovery) 기능을 활성화하여 데이터 손실에 대비하고, 재해 복구 전략을 수립합니다.

## 3. Config Server 대체 방안 (AWS Parameter Store)

### 3.1. 제안 배경 및 목표

기존 Spring Cloud Config Server는 마이크로서비스 환경에서 중앙 집중식 설정 관리를 제공하지만, AWS 환경으로 마이그레이션 시 AWS 네이티브 서비스를 활용하여 운영 복잡성을 줄이고 보안을 강화하는 것이 효율적입니다. AWS Systems Manager Parameter Store는 안전하고 확장 가능한 설정 관리 서비스를 제공하며, 애플리케이션 코드에서 쉽게 접근할 수 있습니다.

### 3.2. Key Naming 규칙 및 구조 설계

AWS Parameter Store의 Key Naming 규칙은 계층적 구조를 활용하여 설정을 체계적으로 관리하는 것이 중요합니다. 다음 규칙을 제안합니다.

`/{Application}/{Environment}/{Service}/{ParameterName}`

*   **`Application`**: 최상위 애플리케이션 그룹 (예: `petclinic`)
*   **`Environment`**: 배포 환경 (예: `dev`, `stg`, `prod`)
*   **`Service`**: 개별 마이크로서비스 이름 (예: `customers-service`, `vets-service`, `api-gateway`)
*   **`ParameterName`**: 실제 설정 파라미터 이름 (예: `database.url`, `database.username`, `jwt.secret`)

**예시:**

*   `/petclinic/dev/customers-service/database.url`
*   `/petclinic/prod/vets-service/database.username`
*   `/petclinic/prod/api-gateway/jwt.secret`

**구조적 장점:**

*   **명확성:** 파라미터의 용도와 소유 서비스를 쉽게 파악할 수 있습니다.
*   **계층적 접근:** 특정 서비스 또는 환경의 모든 파라미터를 한 번에 조회하거나 관리하기 용이합니다.
*   **보안 강화:** 민감한 정보(비밀번호, API 키 등)는 `SecureString` 타입으로 저장하여 암호화하고, IAM 정책을 통해 접근 권한을 세밀하게 제어할 수 있습니다.

### 3.3. 고려 사항

#### 3.3.1. 운영 효율성 (Operational Excellence)

*   **중앙 집중식 관리:** 모든 설정이 Parameter Store에 중앙 집중화되어 관리되므로, 설정 변경 및 배포가 용이합니다.
*   **버전 관리:** Parameter Store는 파라미터의 버전 관리를 지원하여, 변경 이력을 추적하고 필요한 경우 이전 버전으로 롤백할 수 있습니다.
*   **자동화된 설정 주입:** Spring Cloud AWS 라이브러리를 활용하여 애플리케이션 시작 시 Parameter Store에서 설정을 자동으로 로드하도록 구성할 수 있습니다.

#### 3.3.2. 비용 (Cost)

*   **무료 계층:** Parameter Store는 일정량의 파라미터 저장 및 API 호출에 대해 무료 계층을 제공합니다. 대부분의 경우 추가 비용 없이 사용할 수 있습니다.
*   **Advanced Tier:** 더 많은 파라미터 수, 더 큰 파라미터 크기, 더 높은 처리량을 요구하는 경우 Advanced Tier를 사용할 수 있으며, 이에 따른 비용이 발생합니다.

#### 3.3.3. 보안 (Security)

*   **데이터 암호화:** `SecureString` 타입으로 저장된 파라미터는 AWS KMS를 사용하여 자동으로 암호화됩니다. 이는 민감한 정보를 안전하게 보호합니다.
*   **접근 제어:** IAM 정책을 통해 특정 사용자, 역할 또는 서비스에 대한 파라미터 접근 권한을 세밀하게 제어할 수 있습니다. 예를 들어, `customers-service`는 자신의 설정 파라미터에만 접근할 수 있도록 제한할 수 있습니다.
*   **감사:** AWS CloudTrail과 통합되어 파라미터 접근 및 변경 이력을 감사할 수 있습니다.

#### 3.3.4. 고가용성 (Availability)

*   **AWS 관리 서비스:** Parameter Store는 AWS에서 관리하는 서비스이므로, 높은 가용성과 내구성을 보장합니다. 별도의 인프라 관리 없이 안정적으로 사용할 수 있습니다.
*   **리전 복원력:** AWS 리전 내에서 여러 가용 영역에 걸쳐 데이터가 복제되므로, 단일 AZ 장애에도 영향을 받지 않습니다.

## 4. To-Be 아키텍처 다이어그램 (데이터베이스 및 설정 관리 부분)

(이 섹션에는 최종 To-Be 아키텍처 다이어그램의 데이터베이스 및 설정 관리 부분을 시각적으로 표현한 다이어그램이 포함되어야 합니다. 현재는 텍스트로 설명을 대체합니다.)

**데이터베이스 구성:**

*   각 마이크로서비스 (예: `customers-service`, `vets-service`, `visits-service`, `api-gateway`, `admin-server`, `genai-service`)는 독립적인 AWS RDS 인스턴스를 가집니다.
*   각 RDS 인스턴스는 Multi-AZ로 배포되어 고가용성을 확보합니다.
*   필요에 따라 읽기 전용 복제본을 추가하여 읽기 성능을 최적화합니다.

**설정 관리:**

*   모든 서비스의 설정 정보는 AWS Systems Manager Parameter Store에 저장됩니다.
*   Parameter Store의 키는 `/{Application}/{Environment}/{Service}/{ParameterName}` 규칙을 따릅니다.
*   각 마이크로서비스는 Spring Cloud AWS 라이브러리를 통해 Parameter Store에서 자신의 설정을 로드합니다.
*   민감한 정보는 `SecureString` 타입으로 저장되고, IAM 정책을 통해 접근이 제어됩니다.

## 5. 결론 및 다음 단계

본 제안서는 PetClinic 마이크로서비스의 AWS 마이그레이션을 위한 RDS 구성 및 설정 관리 방안을 제시했습니다. '서비스별 논리적 DB 분리'와 'AWS Parameter Store 활용'을 통해 MSA 원칙을 준수하고, 운영 효율성, 비용, 보안, 고가용성을 확보할 수 있을 것으로 기대합니다.

다음 단계로는 각 서비스별 RDS 인스턴스 타입 및 스펙을 구체화하고, Parameter Store에 실제 설정 값들을 마이그레이션하는 작업을 진행해야 합니다. 또한, IaC(CloudFormation 또는 Terraform)를 사용하여 인프라를 코드로 관리하는 방안을 수립해야 합니다.