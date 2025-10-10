# Database Layer (03-database)

## 개요

이 레이어는 Spring PetClinic 마이크로서비스를 위한 Aurora MySQL 클러스터를 구성합니다. AWS Well-Architected Framework의 데이터베이스 원칙을 따라 고가용성, 보안성, 성능을 보장합니다.

**공유 변수 시스템 적용**: 이 레이어는 `shared-variables.tf`에서 정의된 공통 변수를 사용하여 다른 레이어와의 일관성을 보장합니다.

## 아키텍처

```
┌─────────────────────────────────────────────────────────────┐
│                    Database Layer                           │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────┐    ┌─────────────────────────────────┐ │
│  │   Aurora        │    │        Dependencies             │ │
│  │   MySQL         │    │                                 │ │
│  │   Cluster       │◄───┤  • Network Layer (서브넷)       │ │
│  │                 │    │  • Security Layer (보안 그룹)   │ │
│  │  ┌─────────────┐│    │                                 │ │
│  │  │   Writer    ││    └─────────────────────────────────┘ │
│  │  │  Instance   ││                                        │ │
│  │  └─────────────┘│                                        │ │
│  │  ┌─────────────┐│                                        │ │
│  │  │   Reader    ││                                        │ │
│  │  │  Instance   ││                                        │ │
│  │  └─────────────┘│                                        │ │
│  └─────────────────┘                                        │ │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## 주요 구성 요소

### Aurora MySQL 클러스터
- **엔진**: Aurora MySQL 8.0 호환
- **인스턴스 클래스**: db.serverless (Serverless v2)
- **배포**: Multi-AZ (Writer 1개 + Reader 1개)
- **스토리지**: 자동 확장 (최대 128TB)

### 보안 기능
- **암호화**: 저장 시 암호화 (AWS KMS)
- **네트워크**: Private DB 서브넷에 배치
- **인증**: AWS 관리형 비밀번호 (Secrets Manager)
- **접근 제어**: 보안 그룹을 통한 제한적 접근

### 백업 및 복구
- **자동 백업**: 7일 보존
- **백업 윈도우**: 03:00-04:00 UTC
- **Point-in-Time Recovery**: 지원
- **유지보수 윈도우**: 일요일 04:00-05:00 UTC

## 의존성

이 레이어는 다음 레이어들에 의존합니다:

1. **01-network**: Private DB 서브넷 정보
2. **02-security**: Aurora 보안 그룹

## 사용법

### 1. 의존성 레이어 배포
```bash
# Network 레이어 먼저 배포
cd terraform/layers/01-network
terraform init && terraform apply

# Security 레이어 배포
cd ../02-security
terraform init && terraform apply
```

### 2. Database 레이어 배포
```bash
cd ../03-database
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
# 클러스터 상태 확인
aws rds describe-db-clusters --db-cluster-identifier petclinic-dev-aurora-cluster

# 엔드포인트 정보 확인
terraform output connection_info
```

## 출력값

### 주요 출력값
- `cluster_endpoint`: Writer 엔드포인트 (쓰기 작업용)
- `reader_endpoint`: Reader 엔드포인트 (읽기 작업용)
- `connection_info`: 애플리케이션 연결 정보
- `database_summary`: 전체 데이터베이스 정보 요약

### 애플리케이션 연결
```yaml
# Spring Boot application.yml 예시
spring:
  datasource:
    url: ${DATABASE_WRITER_URL}  # terraform output에서 제공
    username: ${DATABASE_USERNAME}
    password: ${DATABASE_PASSWORD}  # Secrets Manager에서 자동 관리
```

## 모니터링

### Performance Insights
- **활성화**: 기본 활성화
- **보존 기간**: 7일 (무료 티어)
- **메트릭**: 쿼리 성능, 대기 이벤트 등

### Enhanced Monitoring
- **간격**: 60초
- **메트릭**: OS 레벨 메트릭 (CPU, 메모리, I/O 등)

### CloudWatch 메트릭
- CPU 사용률
- 데이터베이스 연결 수
- 읽기/쓰기 지연시간
- 스토리지 사용량

## 보안 고려사항

### 네트워크 보안
- Private DB 서브넷에 배치 (인터넷 접근 불가)
- 보안 그룹을 통한 포트 3306 제한적 접근
- VPC 내부 통신만 허용

### 데이터 보안
- 저장 시 암호화 (AWS KMS)
- 전송 중 암호화 (SSL/TLS)
- AWS 관리형 비밀번호 (자동 로테이션)

### 접근 제어
- IAM 데이터베이스 인증 지원
- 최소 권한 원칙 적용
- CloudTrail을 통한 API 호출 감사

## 비용 최적화

### Serverless v2
- **자동 스케일링**: 트래픽에 따라 용량 조정
- **비용 효율성**: 사용한 만큼만 과금
- **최소 용량**: 0.5 ACU (Aurora Capacity Unit)

### 백업 최적화
- **보존 기간**: 7일 (필요에 따라 조정 가능)
- **스냅샷**: 주요 배포 전에만 수동 생성

## 문제 해결

### 일반적인 문제

1. **의존성 에러**
   ```
   Error: Network layer dependencies not ready
   ```
   - 해결: 01-network 레이어가 성공적으로 배포되었는지 확인

2. **보안 그룹 에러**
   ```
   Error: Security layer dependencies not ready
   ```
   - 해결: 02-security 레이어가 성공적으로 배포되었는지 확인

3. **연결 실패**
   - 보안 그룹 규칙 확인
   - 서브넷 라우팅 확인
   - Secrets Manager 비밀번호 확인

### 디버깅 명령어
```bash
# 의존성 상태 확인
terraform output layer_dependencies

# 연결 정보 확인
terraform output connection_info

# 클러스터 상태 확인
aws rds describe-db-clusters --db-cluster-identifier $(terraform output -raw cluster_id)
```

## 업그레이드 및 유지보수

### 엔진 업그레이드
```bash
# 사용 가능한 버전 확인
aws rds describe-db-engine-versions --engine aurora-mysql

# 업그레이드 (유지보수 윈도우에서 자동 수행)
terraform apply -var="engine_version=8.0.mysql_aurora.3.05.0"
```

### 백업 복원
```bash
# Point-in-Time Recovery
aws rds restore-db-cluster-to-point-in-time \
  --source-db-cluster-identifier petclinic-dev-aurora-cluster \
  --db-cluster-identifier petclinic-dev-aurora-cluster-restored \
  --restore-to-time 2024-01-01T12:00:00Z
```

## 참고 자료

- [Aurora MySQL 문서](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/)
- [Aurora Serverless v2 가이드](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-serverless-v2.html)
- [Performance Insights 사용법](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/USER_PerfInsights.html)