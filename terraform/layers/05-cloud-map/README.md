# 05-cloud-map 레이어 - 서비스 디스커버리 (단순화됨)

## 개요

Netflix Eureka를 대체하는 AWS Cloud Map 기반 서비스 디스커버리를 제공합니다. 
과도한 복잡성을 제거하고 기본적인 DNS 기반 서비스 디스커버리 기능만 제공합니다.

## 주요 기능

- **프라이빗 DNS 네임스페이스**: `petclinic.local` 네임스페이스 생성
- **서비스 등록**: ECS 서비스 자동 등록 (customers, vets, visits, admin)
- **DNS 기반 발견**: 표준 DNS 쿼리로 서비스 발견
- **단순화된 설정**: 복잡한 헬스체크, 알람, 모니터링 제거

## 생성 리소스

- `aws_service_discovery_private_dns_namespace`: 프라이빗 DNS 네임스페이스
- `aws_service_discovery_service`: 마이크로서비스별 서비스 등록

## 의존성

- **01-network**: VPC ID 참조

## 사용법

```bash
# 초기화 (backend 설정)
terraform init -backend-config="bucket=petclinic-yeonghyeon-test" \
               -backend-config="key=dev/05-cloud-map/terraform.tfstate" \
               -backend-config="region=ap-northeast-1" \
               -backend-config="profile=petclinic-dev"

# 계획 확인 (공유 변수 시스템 사용)
terraform plan -var="shared_config=$(terraform output -json shared_config)" \
               -var="state_config=$(terraform output -json state_config)"

# 적용
terraform apply -var="shared_config=$(terraform output -json shared_config)" \
                -var="state_config=$(terraform output -json state_config)"
```

### 공유 변수 시스템 사용

이 레이어는 `shared-variables.tf`에서 정의된 공통 변수를 사용합니다:
- `shared_config`: 기본 프로젝트 설정 (name_prefix, environment, aws_region 등)
- `state_config`: Terraform 상태 관리 설정 (bucket_name, region, profile)

## 출력값

- `namespace_id`: 네임스페이스 ID
- `namespace_name`: 네임스페이스 이름
- `service_ids`: 서비스 ID 목록
- `service_dns_names`: DNS 이름 목록

## 마이그레이션 정보

- **기존**: Netflix Eureka Server
- **신규**: AWS Cloud Map
- **장점**: 완전 관리형, DNS 표준, 서버 관리 불필요