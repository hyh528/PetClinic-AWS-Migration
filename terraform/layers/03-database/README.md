# 03-database 레이어 🗄️

## 목차
- [개요](#개요)
- [AWS Aurora 기초 개념](#aws-aurora-기초-개념)
- [우리가 만드는 데이터베이스 구조](#우리가-만드는-데이터베이스-구조)
- [데이터베이스 연결 경로](#데이터베이스-연결-경로)
- [보안 및 암호화](#보안-및-암호화)
- [백업 및 복구 전략](#백업-및-복구-전략)
- [코드 구조](#코드-구조)
- [배포 방법](#배포-방법)
- [문제 해결](#문제-해결)

---

## 개요

**03-database 레이어**는 Spring PetClinic 애플리케이션의 **데이터를 저장하는 Aurora MySQL 클러스터**를 생성합니다.

### 이 레이어가 하는 일
- ✅ Aurora MySQL 클러스터 생성 (Writer + Reader)
- ✅ Private DB 서브넷에 배포 (외부 접근 불가)
- ✅ AWS Secrets Manager로 비밀번호 자동 관리
- ✅ 자동 백업 및 Point-in-Time Recovery 설정
- ✅ Performance Insights 활성화 (성능 모니터링)
- ✅ 스토리지 암호화 적용 (AES-256)

### 다른 레이어와의 관계
```
01-network (Private DB Subnet)
    ↓
02-security (RDS Security Group)
    ↓
03-database (이 레이어) 🗄️
    ↓
    ├─→ 07-application (ECS 서비스가 DB 사용)
    └─→ 06-lambda-genai (Lambda가 RDS Data API 사용)
```

---

## AWS Aurora 기초 개념

### 1. Aurora MySQL이란? 🚀

**쉽게 설명**: Aurora는 AWS가 만든 **MySQL 호환 관계형 데이터베이스**입니다.

일반 MySQL과 비교:

| 특징 | 일반 MySQL (RDS) | Aurora MySQL |
|------|------------------|--------------|
| **성능** | 기본 | 최대 5배 빠름 |
| **가용성** | 단일 또는 다중 AZ | 자동 다중 AZ (3개 복제본) |
| **스토리지** | 수동 확장 | 자동 확장 (10GB → 128TB) |
| **백업** | 수동/자동 | 연속적 자동 백업 |
| **복구** | 시간 소요 | 빠른 복구 (10-30초) |
| **비용** | 낮음 | 약간 높음 (성능 대비 저렴) |

**우리 프로젝트**: Aurora MySQL 8.0.mysql_aurora.3.08.2 사용

---

### 2. Aurora 클러스터 아키텍처 🏗️

Aurora는 **클러스터 단위**로 동작합니다. 1개 클러스터 = Writer 1개 + Reader N개

```
┌──────────────────────────────────────────────────────────┐
│              Aurora MySQL Cluster                        │
│                                                          │
│  ┌─────────────────┐          ┌─────────────────┐      │
│  │  Writer 인스턴스  │          │  Reader 인스턴스  │      │
│  │  (Primary)      │          │  (Read Replica) │      │
│  │                 │          │                 │      │
│  │  쓰기 + 읽기     │  ←─────→ │  읽기 전용       │      │
│  │  (us-west-2a)   │   복제   │  (us-west-2b)   │      │
│  └────────┬────────┘          └────────┬────────┘      │
│           │                            │                │
│           └────────────┬───────────────┘                │
│                        ↓                                │
│         ┌──────────────────────────────┐               │
│         │   Aurora Storage Volume      │               │
│         │   (자동 3 AZ 복제)            │               │
│         │   - 10GB ~ 128TB 자동 확장    │               │
│         │   - 6개 복사본 분산 저장      │               │
│         └──────────────────────────────┘               │
└──────────────────────────────────────────────────────────┘
```

#### Writer vs Reader

| 구분 | Writer (Primary) | Reader (Replica) |
|------|------------------|------------------|
| **용도** | 쓰기 + 읽기 | 읽기 전용 |
| **개수** | 1개 | 0-15개 |
| **엔드포인트** | Cluster Endpoint | Reader Endpoint |
| **장애 대응** | 자동 Failover | Reader → Writer 승격 |
| **비용** | 인스턴스당 과금 | 인스턴스당 과금 |

**우리 프로젝트**: Writer 1개 + Reader 1개 (고가용성)

---

### 3. Aurora 엔드포인트 이해하기 🔌

Aurora는 여러 개의 **엔드포인트**를 제공합니다:

#### a) Cluster Endpoint (Writer Endpoint)
```
petclinic-dev-aurora-cluster.cluster-abc123.us-west-2.rds.amazonaws.com
```

**용도**: 쓰기 작업 (INSERT, UPDATE, DELETE)
**연결 대상**: 항상 Writer 인스턴스
**장애 시**: 자동으로 새 Writer로 연결 변경

#### b) Reader Endpoint
```
petclinic-dev-aurora-cluster.cluster-ro-abc123.us-west-2.rds.amazonaws.com
```

**용도**: 읽기 작업 (SELECT)
**연결 대상**: Reader 인스턴스들 (로드밸런싱)
**장점**: Writer 부하 분산

#### c) Instance Endpoint (개별 인스턴스)
```
petclinic-dev-aurora-writer.abc123.us-west-2.rds.amazonaws.com
petclinic-dev-aurora-reader.abc123.us-west-2.rds.amazonaws.com
```

**용도**: 특정 인스턴스 직접 연결 (일반적으로 사용 안 함)

### 애플리케이션 연결 패턴

```java
// Spring Boot application.yml
spring:
  datasource:
    # 쓰기 작업 (customers-service, vets-service 등)
    writer:
      url: jdbc:mysql://cluster-endpoint:3306/petclinic
      username: petclinic
      password: ${DB_PASSWORD}  # Secrets Manager에서 조회
    
    # 읽기 작업 (조회 전용 쿼리)
    reader:
      url: jdbc:mysql://reader-endpoint:3306/petclinic
      username: petclinic
      password: ${DB_PASSWORD}
```

---

### 4. Aurora Serverless v2 vs Provisioned 💰

우리 프로젝트는 **Aurora Serverless v2**를 사용할 수 있습니다.

| 구분 | Provisioned | Serverless v2 |
|------|-------------|---------------|
| **인스턴스 크기** | 고정 (db.r6g.large 등) | 동적 (0.5 ACU ~ 128 ACU) |
| **스케일링** | 수동 | 자동 (초 단위) |
| **비용** | 시간당 고정 | 사용량 기반 |
| **적합한 경우** | 예측 가능한 트래픽 | 변동이 큰 트래픽 |
| **최소 비용** | $100+/월 | $50+/월 |

**우리 설정**:
```hcl
instance_class = "db.serverless"  # Serverless v2

# Serverless 용량 설정 (모듈에서)
serverlessv2_scaling_configuration {
  min_capacity = 0.5  # 최소 0.5 ACU
  max_capacity = 2.0  # 최대 2 ACU
}
```

**ACU (Aurora Capacity Unit)**: 약 2GB RAM + CPU

---

### 5. AWS Secrets Manager 통합 🔐

**쉽게 설명**: 데이터베이스 비밀번호를 **안전하게 자동 관리**하는 서비스입니다.

#### 기존 방식 (수동 관리)
```
❌ 문제점:
1. 비밀번호를 terraform.tfvars에 평문 저장
2. 환경변수에 하드코딩
3. 비밀번호 변경 시 모든 서비스 재시작 필요
4. Git에 실수로 커밋될 위험
```

#### AWS Secrets Manager 방식 (자동 관리)
```
✅ 장점:
1. Aurora가 비밀번호 자동 생성
2. Secrets Manager에 암호화 저장
3. 자동 로테이션 가능
4. ECS/Lambda가 런타임에 조회
5. Git에 비밀번호 없음
```

#### 동작 원리

```
1. Aurora 생성 시
   Aurora → Secrets Manager: "새 비밀번호 생성하고 저장해줘"
   Secrets Manager → Aurora: "이 비밀번호 사용해: Xy9#mK2p..."

2. ECS 컨테이너 시작 시
   ECS → Secrets Manager: "petclinic DB 비밀번호 알려줘"
   Secrets Manager → ECS: "Xy9#mK2p..."
   ECS → Aurora: JDBC 연결 (비밀번호 사용)

3. 비밀번호 로테이션 시 (선택)
   Secrets Manager → Aurora: "새 비밀번호로 변경: Ab7$nL5q..."
   Secrets Manager → ECS: "새 비밀번호로 재연결해"
```

**우리 설정**:
```hcl
manage_master_user_password = true  # AWS 자동 관리
```

---

## 우리가 만드는 데이터베이스 구조

### 전체 아키텍처 다이어그램

```
┌───────────────────────────────────────────────────────────────────┐
│                    VPC: 10.0.0.0/16                               │
│                                                                   │
│  ╔═══════════════════════════════════════════════════════════╗  │
│  ║  Private App Subnet (us-west-2a)                          ║  │
│  ║  10.0.10.0/24                                             ║  │
│  ║                                                           ║  │
│  ║  ┌──────────────────────────────────────────────┐        ║  │
│  ║  │  ECS Fargate 컨테이너                         │        ║  │
│  ║  │  - customers-service                         │        ║  │
│  ║  │  - vets-service                              │        ║  │
│  ║  │  - visits-service                            │        ║  │
│  ║  └────────────────┬─────────────────────────────┘        ║  │
│  ║                   │                                       ║  │
│  ║                   │ JDBC 연결                             ║  │
│  ║                   │ (3306 포트)                          ║  │
│  ╚═══════════════════╪═══════════════════════════════════════╝  │
│                      │                                           │
│                      ↓                                           │
│  ╔═══════════════════════════════════════════════════════════╗  │
│  ║  Private DB Subnet (us-west-2a)                           ║  │
│  ║  10.0.20.0/24                                             ║  │
│  ║                                                           ║  │
│  ║  ┌────────────────────────────────────────────┐          ║  │
│  ║  │  Aurora MySQL Cluster                      │          ║  │
│  ║  │  ┌──────────────────────────────────┐     │          ║  │
│  ║  │  │  Writer Instance (Primary)       │     │          ║  │
│  ║  │  │  - 쓰기 + 읽기                    │     │          ║  │
│  ║  │  │  - db.serverless (0.5-2 ACU)     │     │          ║  │
│  ║  │  │  - Endpoint: cluster-endpoint    │     │          ║  │
│  ║  │  └──────────────────────────────────┘     │          ║  │
│  ║  │                                            │          ║  │
│  ║  │  ┌──────────────────────────────────┐     │          ║  │
│  ║  │  │  Storage Volume (자동 복제)        │     │          ║  │
│  ║  │  │  - 3 AZ에 6개 복사본              │     │          ║  │
│  ║  │  │  - 10GB ~ 128TB 자동 확장          │     │          ║  │
│  ║  │  │  - AES-256 암호화                │     │          ║  │
│  ║  │  └──────────────────────────────────┘     │          ║  │
│  ║  └────────────────────────────────────────────┘          ║  │
│  ╚═══════════════════════════════════════════════════════════╝  │
│                                                                   │
│  ╔═══════════════════════════════════════════════════════════╗  │
│  ║  Private DB Subnet (us-west-2b)                           ║  │
│  ║  10.0.21.0/24                                             ║  │
│  ║                                                           ║  │
│  ║  ┌────────────────────────────────────────────┐          ║  │
│  ║  │  Reader Instance (Read Replica)            │          ║  │
│  ║  │  - 읽기 전용                                │          ║  │
│  ║  │  - db.serverless (0.5-2 ACU)               │          ║  │
│  ║  │  - Endpoint: reader-endpoint               │          ║  │
│  ║  │  - 복제 지연: < 100ms                       │          ║  │
│  ║  └────────────────────────────────────────────┘          ║  │
│  ╚═══════════════════════════════════════════════════════════╝  │
│                                                                   │
└───────────────────────────────────────────────────────────────────┘

외부 서비스:
┌────────────────────────────┐
│  AWS Secrets Manager       │  ← 비밀번호 자동 저장
│  - petclinic-db-password   │
└────────────────────────────┘

┌────────────────────────────┐
│  CloudWatch Logs           │  ← 슬로우 쿼리 로그
│  - /aws/rds/cluster/...    │
└────────────────────────────┘

┌────────────────────────────┐
│  Performance Insights      │  ← 실시간 성능 모니터링
│  - 쿼리 분석 대시보드        │
└────────────────────────────┘
```

---

### 데이터베이스 스키마

```sql
-- petclinic 데이터베이스
CREATE DATABASE petclinic;
USE petclinic;

-- 테이블 구조 (Spring PetClinic 표준)
CREATE TABLE owners (
  id INT PRIMARY KEY AUTO_INCREMENT,
  first_name VARCHAR(30),
  last_name VARCHAR(30),
  address VARCHAR(255),
  city VARCHAR(80),
  telephone VARCHAR(20)
);

CREATE TABLE pets (
  id INT PRIMARY KEY AUTO_INCREMENT,
  name VARCHAR(30),
  birth_date DATE,
  type_id INT,
  owner_id INT,
  FOREIGN KEY (owner_id) REFERENCES owners(id)
);

CREATE TABLE vets (
  id INT PRIMARY KEY AUTO_INCREMENT,
  first_name VARCHAR(30),
  last_name VARCHAR(30)
);

CREATE TABLE visits (
  id INT PRIMARY KEY AUTO_INCREMENT,
  pet_id INT,
  visit_date DATE,
  description VARCHAR(255),
  FOREIGN KEY (pet_id) REFERENCES pets(id)
);

-- 초기 데이터는 애플리케이션에서 Flyway/Liquibase로 마이그레이션
```

---

## 데이터베이스 연결 경로

### 시나리오 1: ECS 컨테이너 → Aurora (쓰기)

```
1. ECS 컨테이너 시작
   ↓
2. ECS가 Secrets Manager에서 DB 비밀번호 조회
   GET /secrets/petclinic-db-password
   ↓
3. 환경변수로 비밀번호 주입
   DB_PASSWORD=Xy9#mK2p...
   ↓
4. Spring Boot 애플리케이션 시작
   DataSource 초기화:
   - URL: jdbc:mysql://cluster-endpoint:3306/petclinic
   - Username: petclinic
   - Password: ${DB_PASSWORD}
   ↓
5. JDBC 연결 생성
   ECS → Aurora Writer (Private DB Subnet)
   ↓
6. SQL 쿼리 실행
   INSERT INTO owners VALUES (...);
   ↓
7. Aurora Storage에 데이터 저장
   자동으로 3 AZ에 6개 복사본 복제
```

**네트워크 경로**:
```
ECS Container (10.0.10.x)
    ↓ TCP 3306
[RDS Security Group 검사]
    ↓
Aurora Writer (10.0.20.x)
```

---

### 시나리오 2: ECS 컨테이너 → Aurora (읽기)

```
1. 읽기 전용 요청 (예: 고객 목록 조회)
   GET /api/customers
   ↓
2. Spring Boot 읽기 DataSource 사용
   reader:
     url: jdbc:mysql://reader-endpoint:3306/petclinic
   ↓
3. JDBC 연결
   ECS → Aurora Reader (Private DB Subnet)
   ↓
4. SQL 쿼리 실행
   SELECT * FROM owners WHERE city = 'Seattle';
   ↓
5. Aurora Storage에서 데이터 조회
   Writer와 동일한 Storage Volume 공유
```

**장점**: Writer 인스턴스 부하 분산

---

### 시나리오 3: Lambda → Aurora (RDS Data API)

```
1. Lambda 함수 호출 (GenAI 챗봇)
   ↓
2. RDS Data API 사용 (VPC 없이 HTTP로 접근)
   rds-data.execute-statement:
     clusterArn: arn:aws:rds:...:cluster:petclinic-dev
     secretArn: arn:aws:secretsmanager:...:secret:db-password
     sql: "SELECT * FROM owners WHERE name LIKE '%Coco%'"
   ↓
3. RDS Data API가 Aurora에 쿼리
   ↓
4. JSON 형식으로 결과 반환
   {
     "records": [
       [{"stringValue": "1"}, {"stringValue": "Jane"}]
     ]
   }
```

**장점**: Lambda에 VPC 설정 불필요 (콜드 스타트 빠름)

---

## 보안 및 암호화

### 1. 네트워크 격리 🔒

```
✅ Aurora는 Private DB Subnet에 배포
   → 인터넷에서 직접 접근 불가

✅ ECS Security Group에서만 접근 허용
   → 보안 그룹 ID 기반 접근 제어

❌ Public Subnet에 배포 금지
❌ 0.0.0.0/0 접근 금지
```

**보안 그룹 규칙** (02-security 레이어에서 생성):
```hcl
# RDS Security Group
ingress {
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.ecs.id  # ECS SG만
  description              = "Allow MySQL from ECS"
}
```

---

### 2. 스토리지 암호화 🔐

```
✅ AES-256 암호화 (AWS 관리형 키)
✅ 자동 백업도 암호화
✅ 스냅샷도 암호화
✅ 복제본도 암호화
```

**설정**:
```hcl
storage_encrypted = true
kms_key_id        = null  # AWS 관리형 키 사용 (무료)
```

**KMS 고객 관리형 키 사용 시** (선택):
```hcl
kms_key_id = "arn:aws:kms:us-west-2:123456789012:key/abc-123"
# 장점: 키 로테이션 직접 관리
# 단점: KMS 사용료 $1/월
```

---

### 3. 비밀번호 관리 🔑

```
✅ AWS Secrets Manager 자동 관리
✅ 강력한 비밀번호 자동 생성 (32자)
✅ 암호화 저장 (KMS)
✅ 자동 로테이션 가능 (선택)
✅ 버전 관리
```

**비밀번호 조회 방법**:

```bash
# AWS CLI로 조회
aws secretsmanager get-secret-value \
  --secret-id petclinic-dev-aurora-master-password \
  --query 'SecretString' --output text | jq -r '.password'

# 출력: Xy9#mK2p...
```

**ECS에서 자동 주입**:
```json
{
  "containerDefinitions": [{
    "secrets": [
      {
        "name": "DB_PASSWORD",
        "valueFrom": "arn:aws:secretsmanager:...:secret:db-password"
      }
    ]
  }]
}
```

---

### 4. SSL/TLS 연결 강제 (선택) 🔒

```sql
-- Aurora에서 SSL 연결만 허용
ALTER USER 'petclinic'@'%' REQUIRE SSL;
```

**JDBC 연결 URL**:
```java
jdbc:mysql://cluster-endpoint:3306/petclinic?useSSL=true&requireSSL=true
```

---

## 백업 및 복구 전략

### 1. 자동 백업 📦

```
✅ 매일 자동 백업
✅ 보존 기간: 7일 (설정 가능: 1-35일)
✅ 백업 시간: UTC 03:00-04:00 (한국 시간 12:00-13:00)
✅ 백업 중에도 서비스 영향 없음
```

**설정**:
```hcl
backup_retention_period = 7  # 7일간 보존
backup_window           = "03:00-04:00"  # UTC
```

**백업 확인**:
```bash
aws rds describe-db-cluster-snapshots \
  --db-cluster-identifier petclinic-dev-aurora-cluster
```

---

### 2. Point-in-Time Recovery (PITR) ⏰

**쉽게 설명**: **특정 시점으로 데이터베이스를 복원**할 수 있습니다.

```
예시:
- 오늘 14:30에 실수로 데이터 삭제
- 14:25 시점으로 복원 가능
- 최근 5분 전까지 복원 가능
```

**복원 명령**:
```bash
aws rds restore-db-cluster-to-point-in-time \
  --source-db-cluster-identifier petclinic-dev-aurora-cluster \
  --db-cluster-identifier petclinic-dev-aurora-restored \
  --restore-to-time "2025-11-09T14:25:00Z"
```

---

### 3. 수동 스냅샷 📸

**용도**: 중요한 변경 전 백업 (예: 대규모 마이그레이션)

```bash
# 스냅샷 생성
aws rds create-db-cluster-snapshot \
  --db-cluster-identifier petclinic-dev-aurora-cluster \
  --db-cluster-snapshot-identifier before-migration-2025-11-09

# 스냅샷 확인
aws rds describe-db-cluster-snapshots \
  --db-cluster-snapshot-identifier before-migration-2025-11-09

# 스냅샷에서 복원
aws rds restore-db-cluster-from-snapshot \
  --db-cluster-identifier petclinic-restored \
  --snapshot-identifier before-migration-2025-11-09
```

---

### 4. 백업 비용 💰

| 백업 타입 | 비용 |
|----------|------|
| **자동 백업** | DB 크기만큼 무료, 초과분 $0.023/GB/월 |
| **수동 스냅샷** | $0.023/GB/월 |
| **PITR 로그** | 자동 백업에 포함 (무료) |

**예시**:
- DB 크기: 50GB
- 자동 백업: 50GB (무료)
- 수동 스냅샷 3개: 150GB × $0.023 = $3.45/월

---

## 코드 구조

### 파일 구성

```
03-database/
├── main.tf              # Aurora 클러스터 생성
├── data.tf              # 01-network, 02-security 데이터 조회
├── locals.tf            # 로컬 변수 및 의존성 검증
├── variables.tf         # 변수 정의
├── outputs.tf           # 출력값 (다른 레이어에서 사용)
├── backend.tf           # Terraform 상태 저장
├── backend.config       # 백엔드 키 설정
├── terraform.tfvars     # 실제 값 입력
└── README.md            # 이 문서
```

### main.tf 주요 구성

```hcl
module "aurora_cluster" {
  source = "../../modules/database"
  
  # 기본 설정
  name_prefix = "petclinic"
  environment = "dev"
  
  # 네트워크 (01-network에서 가져옴)
  private_db_subnet_ids = local.private_db_subnet_ids
  
  # 보안 (02-security에서 가져옴)
  vpc_security_group_ids = [local.aurora_security_group_id]
  
  # Aurora 엔진
  engine_version = "8.0.mysql_aurora.3.08.2"
  instance_class = "db.serverless"  # Serverless v2
  
  # 데이터베이스
  db_name     = "petclinic"
  db_username = "petclinic"
  db_port     = 3306
  
  # 백업
  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:00-sun:05:00"
  
  # 보안
  storage_encrypted            = true
  manage_master_user_password  = true  # Secrets Manager 자동 관리
  
  # 모니터링
  performance_insights_enabled = true
  monitoring_interval          = 60  # Enhanced Monitoring
}
```

---

## 배포 방법

### 사전 요구사항

1. **01-network 레이어 배포 완료**
```bash
cd ../01-network
terraform output private_db_subnet_ids
# 출력: {0 = "subnet-xxx", 1 = "subnet-yyy"}
```

2. **02-security 레이어 배포 완료**
```bash
cd ../02-security
terraform output aurora_security_group_id
# 출력: sg-xxxxxxxxxxxxxxxxx
```

---

### 배포 순서

#### 1단계: 작업 디렉토리 이동
```bash
cd terraform/layers/03-database
```

#### 2단계: 변수 파일 확인
```bash
cat terraform.tfvars
```

예시:
```hcl
# 공통 설정
name_prefix = "petclinic"
environment = "dev"
aws_region  = "us-west-2"
aws_profile = "default"

# Aurora 설정
engine_version = "8.0.mysql_aurora.3.08.2"
instance_class = "db.serverless"  # 또는 "db.r6g.large"

# 데이터베이스
db_name     = "petclinic"
db_username = "petclinic"
db_port     = 3306

# 백업
backup_retention_period = 7
backup_window           = "03:00-04:00"
maintenance_window      = "sun:04:00-sun:05:00"

# 보안
storage_encrypted           = true
manage_master_user_password = true

# 모니터링
performance_insights_enabled = true
monitoring_interval          = 60

# 백엔드
tfstate_bucket_name = "petclinic-tfstate-oregon-dev"

tags = {
  Project     = "petclinic"
  Environment = "dev"
  ManagedBy   = "terraform"
}
```

#### 3단계: Terraform 초기화
```bash
terraform init \
  -backend-config=../../backend.hcl \
  -backend-config=backend.config
```

#### 4단계: 실행 계획 확인 (중요!)
```bash
terraform plan -var-file=terraform.tfvars
```

**확인사항**:
- Aurora 클러스터 1개
- Writer 인스턴스 1개
- Reader 인스턴스 1개
- DB 서브넷 그룹 1개
- Secrets Manager 시크릿 1개

#### 5단계: 배포 실행
```bash
terraform apply -var-file=terraform.tfvars
```

**소요 시간**: 약 10-15분
- 클러스터 생성: 5분
- Writer 인스턴스: 3-5분
- Reader 인스턴스: 3-5분

#### 6단계: 배포 확인
```bash
# 클러스터 엔드포인트 확인
terraform output cluster_endpoint
# petclinic-dev-aurora-cluster.cluster-abc123.us-west-2.rds.amazonaws.com

# Reader 엔드포인트 확인
terraform output reader_endpoint
# petclinic-dev-aurora-cluster.cluster-ro-abc123.us-west-2.rds.amazonaws.com

# 비밀번호 시크릿 이름 확인
terraform output master_user_secret_name
# (Sensitive) - 직접 조회 필요
```

#### 7단계: 데이터베이스 연결 테스트

**방법 1: MySQL 클라이언트 (Bastion 호스트에서)**
```bash
# 비밀번호 조회
DB_PASSWORD=$(aws secretsmanager get-secret-value \
  --secret-id petclinic-dev-aurora-master-password \
  --query 'SecretString' --output text | jq -r '.password')

# MySQL 연결
mysql -h petclinic-dev-aurora-cluster.cluster-xxx.us-west-2.rds.amazonaws.com \
  -u petclinic \
  -p"$DB_PASSWORD" \
  -D petclinic

# 연결 성공 시
mysql> SHOW DATABASES;
mysql> USE petclinic;
mysql> SHOW TABLES;
```

**방법 2: AWS RDS Data API (Lambda에서)**
```bash
aws rds-data execute-statement \
  --resource-arn "$(terraform output -raw cluster_arn)" \
  --secret-arn "$(terraform output -raw master_user_secret_name)" \
  --database petclinic \
  --sql "SELECT DATABASE(), USER(), NOW();"
```

---

## 문제 해결

### 문제 1: 서브넷 그룹 생성 실패
```
Error: InvalidSubnet: Invalid subnets
```

**원인**: Private DB 서브넷이 2개 이상의 AZ에 없음

**해결**:
```bash
# 서브넷 확인
cd ../01-network
terraform output private_db_subnet_ids

# 최소 2개 AZ에 서브넷 필요
# {0 = "subnet-xxx" (us-west-2a), 1 = "subnet-yyy" (us-west-2b)}
```

---

### 문제 2: 클러스터 생성 타임아웃
```
Error: timeout while waiting for state to become 'available'
```

**원인**: 네트워크 또는 보안 그룹 설정 오류

**해결**:
```bash
# AWS Console에서 클러스터 상태 확인
aws rds describe-db-clusters \
  --db-cluster-identifier petclinic-dev-aurora-cluster \
  --query 'DBClusters[0].Status'

# 상태가 "creating"이면 대기
# 상태가 "failed"이면 에러 로그 확인
aws rds describe-db-cluster-events \
  --db-cluster-identifier petclinic-dev-aurora-cluster \
  --duration 60
```

---

### 문제 3: 연결 거부 (Connection Refused)
```
ERROR 2003 (HY000): Can't connect to MySQL server
```

**디버깅 단계**:

1. **보안 그룹 확인**
```bash
# RDS 보안 그룹 규칙 확인
terraform output security_group_id

aws ec2 describe-security-groups \
  --group-ids sg-xxxxxxxxx \
  --query 'SecurityGroups[0].IpPermissions'

# Inbound 규칙에 ECS SG 있는지 확인
```

2. **엔드포인트 DNS 확인**
```bash
# 엔드포인트가 정상 해석되는지 확인
nslookup petclinic-dev-aurora-cluster.cluster-xxx.us-west-2.rds.amazonaws.com

# IP가 10.0.20.x 또는 10.0.21.x 대역인지 확인 (Private Subnet)
```

3. **포트 확인**
```bash
# 3306 포트 오픈 여부 확인 (ECS 컨테이너에서)
telnet cluster-endpoint 3306

# 또는
nc -zv cluster-endpoint 3306
```

---

### 문제 4: 비밀번호를 알 수 없음
```
Error: master_user_secret_name is sensitive
```

**해결**:
```bash
# Secrets Manager에서 직접 조회
aws secretsmanager list-secrets \
  --filters Key=name,Values=petclinic

# 시크릿 ARN 확인 후
aws secretsmanager get-secret-value \
  --secret-id arn:aws:secretsmanager:... \
  --query 'SecretString' --output text | jq '.'

# 출력:
# {
#   "username": "petclinic",
#   "password": "Xy9#mK2p...",
#   "engine": "mysql",
#   "host": "cluster-endpoint",
#   "port": 3306
# }
```

---

### 문제 5: 성능이 느림
```
쿼리 응답 시간이 1초 이상
```

**디버깅**:

1. **Performance Insights 확인**
```
AWS Console → RDS → Performance Insights
- Top SQL: 어떤 쿼리가 느린지
- Wait Events: 무엇을 기다리는지 (CPU, IO, Lock 등)
```

2. **슬로우 쿼리 로그 활성화**
```sql
-- Aurora에서 실행
SET GLOBAL slow_query_log = 'ON';
SET GLOBAL long_query_time = 1;  -- 1초 이상 쿼리 로깅

-- CloudWatch Logs에서 확인
-- Log Group: /aws/rds/cluster/petclinic-dev-aurora-cluster/slowquery
```

3. **인덱스 추가**
```sql
-- 자주 조회하는 컬럼에 인덱스 추가
CREATE INDEX idx_owner_last_name ON owners(last_name);
CREATE INDEX idx_pet_name ON pets(name);
```

---

### 디버깅 명령어

```bash
# 클러스터 상태 확인
aws rds describe-db-clusters \
  --db-cluster-identifier petclinic-dev-aurora-cluster

# 인스턴스 상태 확인
aws rds describe-db-instances \
  --filters "Name=db-cluster-id,Values=petclinic-dev-aurora-cluster"

# 최근 이벤트 확인
aws rds describe-events \
  --source-type db-cluster \
  --source-identifier petclinic-dev-aurora-cluster \
  --duration 1440  # 최근 24시간

# 백업 확인
aws rds describe-db-cluster-snapshots \
  --db-cluster-identifier petclinic-dev-aurora-cluster

# CloudWatch 메트릭 확인
aws cloudwatch get-metric-statistics \
  --namespace AWS/RDS \
  --metric-name DatabaseConnections \
  --dimensions Name=DBClusterIdentifier,Value=petclinic-dev-aurora-cluster \
  --start-time 2025-11-09T00:00:00Z \
  --end-time 2025-11-09T23:59:59Z \
  --period 3600 \
  --statistics Average
```

---

## 비용 예상

### Aurora Serverless v2

| 구성 요소 | 사양 | 월 비용 (USD) |
|----------|------|---------------|
| Writer 인스턴스 | 0.5-2 ACU | $40-160 |
| Reader 인스턴스 | 0.5-2 ACU | $40-160 |
| Storage | 50GB | $5.75 ($0.115/GB) |
| I/O | 1M requests | $0.20 |
| 백업 (자동) | 50GB | $0 (무료) |
| 백업 (수동) | 100GB | $2.30 |
| **합계 (최소)** | - | **$88** |
| **합계 (평균)** | - | **$150** |

**비용 최적화 팁**:
- 개발 환경: 야간/주말에 Aurora 중지 (수동)
- 최소 ACU 설정: 0.5 (최저 사양)
- Reader 제거: 고가용성 불필요 시

---

## 다음 단계

데이터베이스 레이어 배포가 완료되면:

1. **04-parameter-store**: 설정 값 저장
2. **05-cloud-map**: 서비스 디스커버리
3. **07-application**: ECS 서비스 배포 (DB 사용)

```bash
cd ../04-parameter-store
terraform init -backend-config=../../backend.hcl -backend-config=backend.config
terraform plan -var-file=terraform.tfvars
```

---

## 요약

### 핵심 개념 정리
- ✅ **Aurora MySQL**: AWS 고성능 관계형 DB (MySQL 호환)
- ✅ **Cluster Endpoint**: 쓰기 작업 (Writer)
- ✅ **Reader Endpoint**: 읽기 작업 (부하 분산)
- ✅ **Secrets Manager**: 비밀번호 자동 관리
- ✅ **PITR**: 특정 시점 복원 (최근 5분까지)

### 생성되는 주요 리소스
- Aurora MySQL 클러스터 1개
- Writer 인스턴스 1개 (db.serverless)
- Reader 인스턴스 1개 (db.serverless)
- Secrets Manager 시크릿 1개
- DB 서브넷 그룹 1개

### 보안 설정
```
✅ Private DB Subnet 배포 (인터넷 접근 불가)
✅ ECS Security Group에서만 접근
✅ AES-256 스토리지 암호화
✅ Secrets Manager 비밀번호 관리
✅ SSL/TLS 연결 지원
```

### 연결 정보
```bash
# Writer (쓰기)
jdbc:mysql://cluster-endpoint:3306/petclinic

# Reader (읽기)
jdbc:mysql://reader-endpoint:3306/petclinic

# 사용자: petclinic
# 비밀번호: Secrets Manager에서 조회
```

---

**작성일**: 2025-11-09  
**작성자**: DevOps Team  
**버전**: 1.0
