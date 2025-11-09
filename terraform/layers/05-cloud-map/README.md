# 05-cloud-map 레이어 🗺️

## 목차
- [개요](#개요)
- [AWS Cloud Map 개념](#aws-cloud-map-개념)
- [Netflix Eureka 대체](#netflix-eureka-대체)
- [우리가 생성하는 서비스](#우리가-생성하는-서비스)
- [DNS 기반 디스커버리 동작 원리](#dns-기반-디스커버리-동작-원리)
- [코드 구조](#코드-구조)
- [배포 방법](#배포-방법)
- [문제 해결](#문제-해결)

---

## 개요

**05-cloud-map 레이어**는 마이크로서비스들이 **서로를 찾을 수 있도록** Service Discovery를 제공합니다.
기존 **Netflix Eureka Server**를 **AWS Cloud Map**으로 대체했습니다.

### 이 레이어가 하는 일
- ✅ Private DNS Namespace 생성 (`petclinic.local`)
- ✅ 각 마이크로서비스의 Cloud Map Service 등록
- ✅ DNS 기반 서비스 디스커버리 제공
- ✅ **Eureka Server 제거** - 더 이상 별도 서버 불필요

### 다른 레이어와의 관계
```
01-network (VPC)
    ↓
05-cloud-map (이 레이어) 🗺️
    ↓
07-application (ECS 서비스가 Cloud Map 사용)
```

---

## AWS Cloud Map 개념

### 1. Cloud Map이란? 🗺️

**쉽게 설명**: Cloud Map은 **AWS 관리형 서비스 레지스트리**입니다.

마이크로서비스가 서로의 위치(IP 주소)를 찾을 수 있도록 전화번호부 역할을 합니다.

#### 일반적인 문제 상황

```
Customers Service가 Vets Service를 호출하려면?

❌ 하드코딩:
http://10.0.10.45:8080/api/vets

문제점:
- IP 주소가 변경되면 코드 수정 필요
- 새 인스턴스 추가 시 로드밸런싱 불가
- 장애 발생 인스턴스 자동 제거 불가
```

```
✅ Cloud Map 사용:
http://vets.petclinic.local:8080/api/vets

장점:
- DNS 이름으로 호출 (IP 변경 무관)
- 자동 로드밸런싱 (여러 IP 반환)
- 비정상 인스턴스 자동 제거
```

---

### 2. Private DNS Namespace 📛

**쉽게 설명**: Namespace는 **VPC 내부에서만 사용하는 도메인**입니다.

```
petclinic.local (Private DNS Namespace)
├── customers.petclinic.local    → 10.0.10.x
├── vets.petclinic.local         → 10.0.10.y
├── visits.petclinic.local       → 10.0.10.z
└── admin.petclinic.local        → 10.0.10.w
```

**특징**:
- ✅ VPC 내부에서만 해석 가능
- ✅ 외부 인터넷에서 접근 불가
- ✅ Route 53 Private Hosted Zone 기반

**우리 프로젝트**: `petclinic.local`

---

### 3. Service Discovery 타입

Cloud Map은 3가지 디스커버리 방식을 지원합니다:

| 타입 | 용도 | 등록 방법 | 우리 프로젝트 |
|------|------|----------|--------------|
| **DNS** | DNS 기반 (A 레코드) | ECS 자동 등록 | ✅ 사용 |
| **API** | HTTP API 호출 | SDK로 수동 등록 | ❌ 미사용 |
| **DNS + API** | 두 방식 모두 | ECS 자동 + SDK | ❌ 미사용 |

**우리는 DNS 방식만 사용**:
- ECS가 자동으로 서비스 인스턴스 등록/해제
- 애플리케이션 코드 변경 불필요
- 기존 DNS 클라이언트 사용 가능

---

### 4. Service vs Instance 🔍

```
Cloud Map Service (논리적 서비스)
    ↓
Service Instance (물리적 인스턴스)
```

**예시**:

```
Service: customers.petclinic.local
    ├─ Instance 1: 10.0.10.45 (ECS Task 1)
    ├─ Instance 2: 10.0.10.67 (ECS Task 2)
    └─ Instance 3: 10.0.10.89 (ECS Task 3)
```

**DNS 조회 시**:
```bash
nslookup customers.petclinic.local

# 결과: 3개 IP 모두 반환 (라운드로빈)
Address: 10.0.10.45
Address: 10.0.10.67
Address: 10.0.10.89
```

---

## Netflix Eureka 대체

### 기존 아키텍처 (Netflix Eureka)

```
┌────────────────────────────────────────────────┐
│  Eureka Server (ECS 서비스)                     │
│  - 별도 컨테이너 실행                           │
│  - 8761 포트로 서비스 레지스트리 제공            │
│  - 리소스 사용: 512 CPU, 1024 MB 메모리         │
│  - 각 서비스가 30초마다 하트비트 전송            │
└────────────────────────────────────────────────┘
              ↓ REST API 호출
┌────────────────────────────────────────────────┐
│  Microservices (customers, vets, visits)       │
│  - Eureka Client 의존성 필요                   │
│  - 시작 시 Eureka에 등록                       │
│  - 다른 서비스 호출 시 Eureka에서 IP 조회       │
└────────────────────────────────────────────────┘
```

**문제점**:
- Eureka Server가 단일 장애점 (SPOF)
- 추가 ECS 서비스 운영 비용 (~$30/월)
- Eureka Client 의존성 추가 필요
- 하트비트 트래픽 발생

---

### 새 아키텍처 (AWS Cloud Map)

```
┌────────────────────────────────────────────────┐
│  AWS Cloud Map (관리형 서비스)                  │
│  - Private DNS Namespace: petclinic.local      │
│  - ECS가 자동으로 인스턴스 등록/해제            │
│  - 고가용성 (AWS 관리형)                        │
│  - 추가 비용 없음 (무료)                        │
└────────────────────────────────────────────────┘
              ↓ DNS 조회
┌────────────────────────────────────────────────┐
│  Microservices (customers, vets, visits)       │
│  - Eureka Client 제거                          │
│  - DNS 이름으로 직접 호출                       │
│  - vets.petclinic.local:8080                   │
└────────────────────────────────────────────────┘
```

**장점**:
- ✅ Eureka Server 제거로 **비용 절감** (~$30/월)
- ✅ **고가용성** (AWS 관리형)
- ✅ **코드 간소화** (Eureka Client 의존성 제거)
- ✅ **자동 등록** (ECS가 자동 처리)
- ✅ **표준 DNS** (특별한 라이브러리 불필요)

---

## 우리가 생성하는 서비스

### 1. Private DNS Namespace

```hcl
# main.tf
namespace_name = "petclinic.local"
```

**생성 결과**:
- Namespace ID: `ns-xxxxxxxxxxxxxxxxx`
- Route 53 Private Hosted Zone: `petclinic.local` (VPC 연결됨)

---

### 2. Cloud Map Services (4개)

```hcl
# main.tf
microservices = ["customers", "vets", "visits", "admin"]
```

**생성되는 서비스**:

| Service Name | DNS Name | 포트 | 용도 |
|-------------|----------|------|------|
| **customers** | `customers.petclinic.local` | 8080 | 고객 관리 |
| **vets** | `vets.petclinic.local` | 8080 | 수의사 관리 |
| **visits** | `visits.petclinic.local` | 8080 | 진료 기록 관리 |
| **admin** | `admin.petclinic.local` | 9090 | Spring Boot Admin |

**DNS TTL**: 60초
- DNS 캐시 유지 시간
- 짧을수록 변경사항이 빠르게 반영되지만 DNS 조회 빈도 증가

---

### 3. Service 설정 상세

각 Cloud Map Service는 다음 설정을 갖습니다:

```hcl
# 모듈 내부 (참고용)
resource "aws_service_discovery_service" "this" {
  name = "customers"
  
  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.this.id
    
    dns_records {
      type = "A"      # IPv4 주소
      ttl  = 60       # 60초 캐시
    }
    
    routing_policy = "MULTIVALUE"  # 모든 정상 IP 반환
  }
  
  health_check_custom_config {
    failure_threshold = 1  # 1번 실패 시 제거
  }
}
```

**주요 설정**:
- **DNS 레코드 타입**: A (IPv4)
- **라우팅 정책**: MULTIVALUE (여러 IP 동시 반환)
- **헬스체크**: ECS 헬스체크 기반 자동 등록/해제

---

## DNS 기반 디스커버리 동작 원리

### 시나리오 1: Customers Service가 Vets Service 호출

```
1. Customers Service 시작
   ↓
2. Spring Boot 애플리케이션 초기화
   RestTemplate 또는 WebClient 설정
   ↓
3. Vets Service 호출 요청
   GET http://vets.petclinic.local:8080/api/vets
   ↓
4. DNS 조회 (VPC DNS Resolver)
   Query: vets.petclinic.local
   ↓
5. Cloud Map 응답
   Answer: 10.0.10.67, 10.0.10.89
   ↓
6. HTTP 요청 전송
   → 10.0.10.67:8080 (첫 번째 IP 사용)
   ↓
7. Vets Service 응답
   ← 200 OK + JSON 데이터
```

---

### 시나리오 2: ECS Task 시작 시 자동 등록

```
1. ECS가 새 Customers Task 시작
   Task IP: 10.0.10.45
   ↓
2. ECS Service Discovery 설정 확인
   Service: customers.petclinic.local
   ↓
3. Cloud Map에 Instance 자동 등록
   POST /RegisterInstance
   {
     "ServiceId": "srv-xxx",
     "InstanceId": "task-abc123",
     "Attributes": {
       "AWS_INSTANCE_IPV4": "10.0.10.45",
       "AWS_INSTANCE_PORT": "8080"
     }
   }
   ↓
4. Route 53 DNS 레코드 생성
   customers.petclinic.local → 10.0.10.45
   ↓
5. 이제 다른 서비스가 DNS 조회 시 새 IP 포함됨
```

---

### 시나리오 3: ECS Task 종료 시 자동 해제

```
1. ECS가 Vets Task 종료 (배포 또는 장애)
   Task IP: 10.0.10.67
   ↓
2. ECS가 Cloud Map에 해제 요청
   POST /DeregisterInstance
   {
     "ServiceId": "srv-yyy",
     "InstanceId": "task-def456"
   }
   ↓
3. Route 53 DNS 레코드 삭제
   vets.petclinic.local → 10.0.10.67 (제거됨)
   ↓
4. DNS 조회 시 해당 IP 제외
   남은 IP: 10.0.10.89만 반환
   ↓
5. 새로운 요청은 정상 인스턴스로만 전달
```

**장점**: 
- 수동 작업 불필요
- 장애 인스턴스 자동 제거 (60초 이내)

---

### DNS 캐싱 고려사항

```
문제: DNS 캐시로 인한 지연

ECS Task 종료 → DNS 레코드 삭제
    ↓
애플리케이션 DNS 캐시: 60초 (TTL)
    ↓
60초 동안은 여전히 종료된 IP 사용 시도 가능
    ↓
Connection Refused 에러 발생
    ↓
재시도 로직으로 다른 IP 사용
```

**해결책**:
1. **짧은 TTL**: 60초 (기본값)
2. **재시도 로직**: Spring Retry 사용
3. **Circuit Breaker**: Resilience4j 사용

---

## 코드 구조

### 파일 구성

```
05-cloud-map/
├── main.tf              # Cloud Map 모듈 호출
├── data.tf              # 01-network 레이어 데이터 조회
├── variables.tf         # 변수 정의
├── outputs.tf           # 출력값
├── backend.tf           # Terraform 상태 저장
├── backend.config       # 백엔드 키 설정
├── terraform.tfvars     # 실제 값 입력
└── README.md            # 이 문서
```

---

### main.tf - 모듈 호출

```hcl
module "cloud_map" {
  source = "../../modules/cloud-map"
  
  # 기본 설정
  name_prefix = "petclinic"
  environment = "dev"
  
  # VPC 설정 (01-network에서 가져옴)
  vpc_id = data.terraform_remote_state.network.outputs.vpc_id
  
  # 네임스페이스 이름
  namespace_name = "petclinic.local"
  
  # 마이크로서비스 목록
  microservices = ["customers", "vets", "visits", "admin"]
  
  # DNS TTL
  dns_ttl = 60  # 60초
  
  # 태그
  tags = local.common_tags
}
```

**중요 포인트**:
- `vpc_id`: 01-network에서 가져옴
- `microservices`: 실제 배포할 서비스 이름
- `dns_ttl`: 60초 (짧음 = 빠른 변경 반영)

---

### outputs.tf - 출력값

```hcl
output "namespace_id" {
  description = "프라이빗 DNS 네임스페이스 ID"
  value       = module.cloud_map.namespace_id
}

output "namespace_name" {
  description = "프라이빗 DNS 네임스페이스 이름"
  value       = module.cloud_map.namespace_name
  # 출력: "petclinic.local"
}

output "service_ids" {
  description = "서비스 디스커버리 서비스 ID 목록"
  value       = module.cloud_map.service_ids
  # 출력: { customers = "srv-xxx", vets = "srv-yyy", ... }
}

output "service_dns_names" {
  description = "각 마이크로서비스의 DNS 이름"
  value       = module.cloud_map.service_dns_names
  # 출력: { 
  #   customers = "customers.petclinic.local",
  #   vets = "vets.petclinic.local",
  #   visits = "visits.petclinic.local",
  #   admin = "admin.petclinic.local"
  # }
}
```

---

## 배포 방법

### 사전 요구사항

1. **01-network 레이어 배포 완료**
```bash
cd ../01-network
terraform output vpc_id
# 출력: vpc-xxxxxxxxxxxxxxxxx
```

---

### 배포 순서

#### 1단계: 작업 디렉토리 이동
```bash
cd terraform/layers/05-cloud-map
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

#### 4단계: 실행 계획 확인
```bash
terraform plan -var-file=terraform.tfvars
```

**확인사항**:
- Private DNS Namespace 1개 (`petclinic.local`)
- Cloud Map Service 4개 (customers, vets, visits, admin)
- Route 53 Private Hosted Zone 1개

#### 5단계: 배포 실행
```bash
terraform apply -var-file=terraform.tfvars
```

**소요 시간**: 약 2-3분

#### 6단계: 배포 확인
```bash
# Namespace 확인
terraform output namespace_name
# petclinic.local

# Service DNS 이름 확인
terraform output service_dns_names
# {
#   customers = "customers.petclinic.local"
#   vets = "vets.petclinic.local"
#   visits = "visits.petclinic.local"
#   admin = "admin.petclinic.local"
# }

# AWS CLI로 Cloud Map 확인
aws servicediscovery list-namespaces

aws servicediscovery list-services \
  --filters Name=NAMESPACE_ID,Values=$(terraform output -raw namespace_id)
```

---

## 문제 해결

### 문제 1: VPC ID를 찾을 수 없음
```
Error: vpc_id not found in network remote state
```

**원인**: 01-network 레이어가 배포되지 않음

**해결**:
```bash
cd ../01-network
terraform apply -var-file=terraform.tfvars

cd ../05-cloud-map
terraform apply -var-file=terraform.tfvars
```

---

### 문제 2: DNS가 해석되지 않음
```
ERROR: UnknownHostException: vets.petclinic.local
```

**원인**: ECS Task가 VPC DNS Resolver를 사용하지 않음

**디버깅**:

1. **VPC DNS 설정 확인**
```bash
aws ec2 describe-vpcs \
  --vpc-ids vpc-xxxxxxxxx \
  --query 'Vpcs[0].[EnableDnsSupport,EnableDnsHostnames]'

# 출력: [true, true] 확인
```

2. **Private Hosted Zone 확인**
```bash
# Route 53에서 petclinic.local 확인
aws route53 list-hosted-zones-by-vpc \
  --vpc-id vpc-xxxxxxxxx \
  --vpc-region us-west-2

# petclinic.local이 VPC에 연결되어 있는지 확인
```

3. **DNS 테스트 (ECS Task 내부에서)**
```bash
# ECS 컨테이너에 접속
aws ecs execute-command \
  --cluster petclinic-dev-cluster \
  --task task-id \
  --container customers-service \
  --interactive \
  --command "/bin/sh"

# DNS 조회
nslookup vets.petclinic.local
dig vets.petclinic.local

# 예상 출력:
# Address: 10.0.10.x
```

---

### 문제 3: 인스턴스가 등록되지 않음
```
nslookup customers.petclinic.local
# NXDOMAIN (도메인 없음)
```

**원인**: ECS Service에 Service Discovery 설정 누락

**확인**:
```bash
# ECS Service 설정 확인
aws ecs describe-services \
  --cluster petclinic-dev-cluster \
  --services customers-service \
  --query 'services[0].serviceRegistries'

# 출력:
# [
#   {
#     "registryArn": "arn:aws:servicediscovery:...:service/srv-xxx"
#   }
# ]
```

**해결**: 07-application 레이어에서 Service Discovery 설정 추가 필요

---

### 문제 4: 여러 IP가 반환되지 않음
```
nslookup customers.petclinic.local
# 1개 IP만 반환
```

**원인**: ECS Task가 1개만 실행 중

**확인**:
```bash
# ECS Task 개수 확인
aws ecs describe-services \
  --cluster petclinic-dev-cluster \
  --services customers-service \
  --query 'services[0].[desiredCount,runningCount]'

# Cloud Map Instance 확인
aws servicediscovery list-instances \
  --service-id srv-xxxxxxxxx
```

**해결**: ECS Service의 `desired_count` 증가

---

### 디버깅 명령어

```bash
# 1. Namespace 목록 조회
aws servicediscovery list-namespaces

# 2. 특정 Namespace의 Service 조회
aws servicediscovery list-services \
  --filters Name=NAMESPACE_ID,Values=ns-xxxxxxxxx

# 3. Service Instance 조회
aws servicediscovery list-instances \
  --service-id srv-xxxxxxxxx

# 4. Instance 상세 정보
aws servicediscovery get-instance \
  --service-id srv-xxxxxxxxx \
  --instance-id task-abc123

# 5. Route 53 Private Hosted Zone 확인
aws route53 list-hosted-zones

# 6. DNS 레코드 조회
aws route53 list-resource-record-sets \
  --hosted-zone-id Z1234567890ABC

# 7. VPC DNS 설정 확인
aws ec2 describe-vpcs \
  --vpc-ids vpc-xxxxxxxxx \
  --query 'Vpcs[0].[EnableDnsSupport,EnableDnsHostnames]'
```

---

## 비용 예상

### Cloud Map 비용

| 구성 요소 | 단위 | 개수 | 월 비용 (USD) |
|----------|------|------|---------------|
| Private DNS Namespace | 1개 | 1 | $0 (무료) |
| Cloud Map Service | 4개 | 4 | $0 (무료) |
| Service Instance 등록 | 인스턴스당 | 8개 | $0 (무료) |
| DNS 쿼리 | 100만 쿼리 | < 1M | $0 (무료) |
| **합계** | - | - | **$0** |

**무료 티어**:
- Private DNS Namespace: **무료**
- Service 등록: **무료**
- Instance 등록/해제: **무료**
- DNS 쿼리: **월 100만 건까지 무료**

**Public DNS Namespace** (사용 안 함):
- $0.50/개/월
- 우리는 Private만 사용하므로 무료

---

## Eureka Server 제거로 인한 비용 절감

### 비용 비교

| 항목 | Eureka Server | Cloud Map | 절감액 |
|------|---------------|-----------|--------|
| ECS 서비스 | $30/월 | $0 | $30 |
| ALB 리스너 | $16/월 | $0 | $16 |
| CloudWatch Logs | $2/월 | $0 | $2 |
| **합계** | **$48/월** | **$0** | **$48/월** |

**연간 절감액**: **$576/년**

**Config Server + Eureka Server 제거**:
- Config Server: $38/월
- Eureka Server: $48/월
- **합계 절감**: **$86/월** ($1,032/년)

---

## 다음 단계

Cloud Map 레이어 배포가 완료되면:

1. **06-lambda-genai**: Lambda GenAI 챗봇 배포
2. **07-application**: ECS 서비스 배포 (Cloud Map 사용)

```bash
cd ../06-lambda-genai
terraform init -backend-config=../../backend.hcl -backend-config=backend.config
terraform plan -var-file=terraform.tfvars
```

---

## 요약

### 핵심 개념 정리
- ✅ **Cloud Map**: AWS 관리형 서비스 레지스트리
- ✅ **Private DNS Namespace**: VPC 내부 전용 도메인 (`petclinic.local`)
- ✅ **DNS 기반 디스커버리**: 표준 DNS로 서비스 위치 찾기
- ✅ **자동 등록/해제**: ECS가 자동으로 처리

### 생성되는 리소스
- Private DNS Namespace: 1개 (`petclinic.local`)
- Cloud Map Service: 4개 (customers, vets, visits, admin)
- Route 53 Private Hosted Zone: 1개

### DNS 이름
```
customers.petclinic.local:8080
vets.petclinic.local:8080
visits.petclinic.local:8080
admin.petclinic.local:9090
```

### 애플리케이션 사용
```java
// Spring Boot RestTemplate
String url = "http://vets.petclinic.local:8080/api/vets";
ResponseEntity<List<Vet>> response = restTemplate.exchange(
    url, 
    HttpMethod.GET, 
    null, 
    new ParameterizedTypeReference<List<Vet>>() {}
);
```

### 비용
- **무료** (Private DNS Namespace)
- Eureka Server 제거로 **$48/월 절감**

---

**작성일**: 2025-11-09  
**작성자**: DevOps Team  
**버전**: 1.0
