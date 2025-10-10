# Parameter Store Layer (04-parameter-store)

## 개요

이 레이어는 Spring PetClinic 마이크로서비스를 위한 AWS Systems Manager Parameter Store를 구성합니다. Spring Cloud Config Server를 대체하여 중앙화된 설정 관리를 제공하며, AWS Well-Architected Framework의 운영 우수성 원칙을 따릅니다.

**공유 변수 시스템 적용**: 이 레이어는 `shared-variables.tf`에서 정의된 공통 변수를 사용하여 다른 레이어와의 일관성을 보장합니다.

## 아키텍처

```
┌─────────────────────────────────────────────────────────────┐
│                Parameter Store Layer                        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────┐    ┌─────────────────────────────────┐ │
│  │   Parameter     │    │        Dependencies             │ │
│  │   Store         │    │                                 │ │
│  │   Module        │◄───┤  • Database Layer (Aurora)     │ │
│  │                 │    │                                 │ │
│  │  ┌─────────────┐│    └─────────────────────────────────┘ │
│  │  │   Basic     ││                                        │ │
│  │  │ Parameters  ││                                        │ │
│  │  └─────────────┘│                                        │ │
│  │  ┌─────────────┐│                                        │ │
│  │  │ Database    ││                                        │ │
│  │  │ Parameters  ││                                        │ │
│  │  └─────────────┘│                                        │ │
│  └─────────────────┘                                        │ │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## 주요 구성 요소

### Spring Cloud Config Server 대체
- **목적**: 중앙화된 설정 관리
- **장점**: AWS 네이티브 서비스, 서버 관리 불필요
- **통합**: Spring Cloud AWS를 통한 자동 설정 주입

### 파라미터 구조
```
/petclinic/
├── common/
│   ├── spring.profiles.active = "mysql,aws"
│   └── logging.level.root = "INFO"
└── {environment}/
    ├── customers/
    │   ├── server.port = "8080"
    │   ├── database.url = "jdbc:mysql://aurora-endpoint:3306/petclinic_customers"
    │   └── database.username = "petclinic"
    ├── vets/
    │   ├── server.port = "8080"
    │   ├── database.url = "jdbc:mysql://aurora-endpoint:3306/petclinic_vets"
    │   └── database.username = "petclinic"
    ├── visits/
    │   ├── server.port = "8080"
    │   ├── database.url = "jdbc:mysql://aurora-endpoint:3306/petclinic_visits"
    │   └── database.username = "petclinic"
    └── admin/
        └── server.port = "9090"
```

### 단순화된 설정
- **기본 파라미터**: Spring 프로파일, 로깅 레벨, 서버 포트
- **데이터베이스 파라미터**: Aurora 엔드포인트 기반 동적 연결 정보
- **복잡성 제거**: KMS, IAM, 고급 로깅 설정 제거

## 의존성

이 레이어는 다음 레이어에 의존합니다:

1. **03-database**: Aurora 클러스터 엔드포인트 정보

## 사용법

### 1. 의존성 레이어 배포
```bash
# Database 레이어 먼저 배포
cd terraform/layers/03-database
terraform init && terraform apply
```

### 2. Parameter Store 레이어 배포
```bash
cd ../04-parameter-store
terraform init

# 공유 변수 시스템을 사용한 배포
terraform plan \
  -var="shared_config=$(terraform -chdir=../../ output -json shared_config)" \
  -var="state_config=$(terraform -chdir=../../ output -json state_config)"

terraform apply \
  -var="shared_config=$(terraform -chdir=../../ output -json shared_config)" \
  -var="state_config=$(terraform -chdir=../../ output -json state_config)"
```

> **참고**: 이 레이어는 공유 변수 시스템을 사용합니다. 루트 디렉토리의 `shared-variables.tf`에서 정의된 공통 설정을 사용하여 일관성을 보장합니다.

### 3. 배포 확인
```bash
# 파라미터 확인
aws ssm get-parameters-by-path --path "/petclinic" --recursive

# 출력값 확인
terraform output parameter_count
terraform output migration_summary
```

## 출력값

### 주요 출력값
- `parameter_count`: 생성된 파라미터 총 개수
- `parameter_prefix`: Parameter Store 파라미터 접두사
- `database_connection_ready`: 데이터베이스 연결 설정 준비 상태
- `migration_summary`: Spring Cloud Config 마이그레이션 요약

### Spring Boot 애플리케이션 연결
```yaml
# application.yml 예시
spring:
  cloud:
    aws:
      paramstore:
        enabled: true
        prefix: /petclinic
        profile-separator: /
        fail-fast: true
      region:
        static: ap-northeast-2
  profiles:
    active: mysql,aws
```

## 마이그레이션 상태

### Spring Cloud Config Server 대체 완료
- ✅ **Config Server 제거**: 별도 서버 관리 불필요
- ✅ **Parameter Store 활용**: AWS 네이티브 서비스 사용
- ✅ **중앙화된 설정**: 모든 마이크로서비스 설정 통합 관리
- ✅ **동적 연결 정보**: Aurora 엔드포인트 자동 참조

### 단순화 완료
- ✅ **복잡성 제거**: 고급 설정들 제거 (KMS, IAM, 로깅 등)
- ✅ **기본 파라미터만 유지**: 핵심 설정에 집중
- ✅ **의존성 최소화**: Database 레이어만 의존

## 보안 고려사항

### 네트워크 보안
- VPC 엔드포인트를 통한 안전한 Parameter Store 접근
- Private 서브넷에서 인터넷 경유 없이 접근

### 데이터 보안
- 기본 암호화 적용 (AWS 관리형 키)
- 민감한 정보는 Secrets Manager와 분리 관리

### 접근 제어
- IAM 역할을 통한 최소 권한 접근
- 서비스별 파라미터 경로 분리

## 비용 최적화

### Parameter Store 비용
- **표준 파라미터**: 무료 (10,000개까지)
- **고급 파라미터**: 사용하지 않음 (비용 절감)
- **API 호출**: 표준 요금 적용

### 운영 비용 절감
- **서버 관리 불필요**: Config Server 대비 운영 비용 제거
- **자동 스케일링**: AWS 관리형 서비스의 장점
- **유지보수 최소화**: 패치, 업데이트 자동 관리

## 문제 해결

### 일반적인 문제

1. **의존성 에러**
   ```
   Error: Database layer dependencies not ready
   ```
   - 해결: 03-database 레이어가 성공적으로 배포되었는지 확인

2. **파라미터 접근 실패**
   - IAM 역할 권한 확인
   - VPC 엔드포인트 연결 상태 확인
   - Parameter Store 서비스 가용성 확인

3. **Aurora 엔드포인트 참조 실패**
   - Database 레이어 출력값 확인
   - 상태 파일 경로 확인

### 디버깅 명령어
```bash
# 의존성 상태 확인
terraform output layer_dependencies

# 파라미터 개수 확인
terraform output parameter_count

# 마이그레이션 상태 확인
terraform output migration_summary

# AWS CLI로 파라미터 확인
aws ssm get-parameters-by-path --path "/petclinic" --recursive
```

## 업그레이드 및 유지보수

### 파라미터 추가
```bash
# 새로운 파라미터 추가 시 locals 블록 수정 후
terraform plan
terraform apply
```

### 설정 변경
```bash
# 파라미터 값 변경
aws ssm put-parameter --name "/petclinic/dev/customers/server.port" --value "8081" --overwrite

# 또는 Terraform으로 관리
terraform apply
```

## 참고 자료

- [AWS Systems Manager Parameter Store](https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-parameter-store.html)
- [Spring Cloud AWS Parameter Store](https://docs.awspring.io/spring-cloud-aws/docs/current/reference/html/index.html#parameter-store)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)