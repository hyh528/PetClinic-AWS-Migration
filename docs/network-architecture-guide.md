# AWS VPC 네트워크 아키텍처 완전 가이드

## 목차
1. [개요](#1-개요)
2. [네트워크 기본 개념](#2-네트워크-기본-개념)
3. [VPC 구성 요소](#3-vpc-구성-요소)
4. [서브넷 설계](#4-서브넷-설계)
5. [라우팅 테이블](#5-라우팅-테이블)
6. [게이트웨이](#6-게이트웨이)
7. [트래픽 흐름 분석](#7-트래픽-흐름-분석)
8. [보안 설계](#8-보안-설계)
9. [고가용성 설계](#9-고가용성-설계)
10. [실제 구현 코드](#10-실제-구현-코드)

---

## 1. 개요

### 1.1. 프로젝트 네트워크 아키텍처
Spring PetClinic 마이크로서비스를 위한 AWS VPC 기반 네트워크 인프라입니다. 이 문서는 네트워크를 처음 접하는 사람도 이해할 수 있도록 단계별로 설명합니다.

### 1.2. 핵심 설계 원칙
- **보안 우선**: 계층별 네트워크 격리
- **고가용성**: 2개 가용 영역(AZ) 사용
- **확장성**: IPv4/IPv6 듀얼스택 지원
- **비용 효율성**: 필요한 리소스만 생성

### 1.3. 전체 네트워크 구조 개요
```
인터넷
    ↓
Internet Gateway (IGW)
    ↓
Public Subnet (ALB, NAT Gateway)
    ↓
Private App Subnet (ECS 컨테이너)
    ↓
Private DB Subnet (Aurora 데이터베이스)
```

---

## 2. 네트워크 기본 개념

### 2.1. IP 주소와 CIDR 블록

#### IP 주소란?
IP 주소는 네트워크에서 각 장치를 식별하는 고유한 주소입니다. 마치 집 주소와 같습니다.

**예시**: `10.0.1.5`
- 10.0.1: 네트워크 부분 (동네)
- 5: 호스트 부분 (집 번호)

#### CIDR 표기법
CIDR(Classless Inter-Domain Routing)는 IP 주소 범위를 표현하는 방법입니다.

**예시**: `10.0.1.0/24`
- 10.0.1.0: 네트워크 주소
- /24: 앞의 24비트가 네트워크 부분 (나머지 8비트는 호스트용)
- 사용 가능한 IP: 10.0.1.0 ~ 10.0.1.255 (256개)

### 2.2. 프라이빗 vs 퍼블릭 IP

#### 프라이빗 IP 주소 범위
- 10.0.0.0/8 (10.0.0.0 ~ 10.255.255.255) ← **우리가 사용**
- 172.16.0.0/12 (172.16.0.0 ~ 172.31.255.255)
- 192.168.0.0/16 (192.168.0.0 ~ 192.168.255.255)

#### 왜 프라이빗 IP를 사용하나요?
1. **보안**: 인터넷에서 직접 접근 불가
2. **비용**: 퍼블릭 IP는 유료, 프라이빗 IP는 무료
3. **주소 절약**: 같은 프라이빗 IP를 여러 네트워크에서 재사용 가능

### 2.3. IPv6 기본 개념

#### IPv6란?
IPv4 주소 고갈 문제를 해결하기 위한 차세대 인터넷 프로토콜입니다.

**특징**:
- 128비트 주소 (IPv4는 32비트)
- 거의 무한한 주소 공간
- 보안 기능 내장

**예시**: `2001:db8::/32`

---

## 3. VPC 구성 요소

### 3.1. VPC (Virtual Private Cloud)란?

VPC는 AWS 클라우드에서 논리적으로 격리된 가상 네트워크입니다. 마치 자신만의 데이터센터를 클라우드에 만드는 것과 같습니다.

#### 우리 VPC 설정
```yaml
VPC CIDR: 10.0.0.0/16
- 사용 가능한 IP 주소: 65,536개
- 네트워크 범위: 10.0.0.0 ~ 10.0.255.255
- IPv6: Amazon 제공 /56 블록 (자동 할당)
```

#### VPC 핵심 기능
1. **DNS 해석**: 리소스 간 이름으로 통신 가능
2. **네트워크 격리**: 다른 VPC와 완전 분리
3. **보안 제어**: 세밀한 네트워크 접근 제어

### 3.2. 가용 영역 (Availability Zone)

#### 가용 영역이란?
AWS 리전 내의 물리적으로 분리된 데이터센터입니다. 각 AZ는 독립적인 전력, 냉각, 네트워크를 가집니다.

#### 우리가 사용하는 AZ
- **ap-northeast-2a** (서울 리전의 첫 번째 AZ)
- **ap-northeast-2c** (서울 리전의 세 번째 AZ)

#### 왜 2개 AZ를 사용하나요?
1. **고가용성**: 한 AZ가 장애나도 서비스 계속 운영
2. **로드 분산**: 트래픽을 여러 AZ에 분산
3. **AWS 요구사항**: RDS 등 일부 서비스는 Multi-AZ 필수

---

## 4. 서브넷 설계

### 4.1. 서브넷이란?

서브넷은 VPC 내의 IP 주소 범위입니다. VPC를 더 작은 네트워크로 나누는 것입니다.

**비유**: VPC가 아파트 단지라면, 서브넷은 각 동(棟)입니다.

### 4.2. 서브넷 유형별 설명

#### 4.2.1. Public Subnet (퍼블릭 서브넷)

**용도**: 인터넷에서 직접 접근해야 하는 리소스
**배치 리소스**: Application Load Balancer, NAT Gateway

```yaml
Public Subnet 구성:
- ap-northeast-2a: 10.0.1.0/24 (256개 IP)
- ap-northeast-2c: 10.0.2.0/24 (256개 IP)

특징:
- 인터넷 게이트웨이로 직접 라우팅
- 퍼블릭 IP 자동 할당
- 인터넷에서 직접 접근 가능
```

**실제 IP 할당 예시**:
```
10.0.1.0    - 네트워크 주소 (사용 불가)
10.0.1.1    - VPC 라우터 (AWS 예약)
10.0.1.2    - DNS 서버 (AWS 예약)
10.0.1.3    - 미래 사용을 위해 예약 (AWS)
10.0.1.4    - ALB 첫 번째 IP
10.0.1.5    - NAT Gateway IP
...
10.0.1.255  - 브로드캐스트 주소 (사용 불가)
```

#### 4.2.2. Private App Subnet (프라이빗 앱 서브넷)

**용도**: 애플리케이션 서버 (ECS 컨테이너)
**배치 리소스**: ECS Fargate 태스크

```yaml
Private App Subnet 구성:
- ap-northeast-2a: 10.0.3.0/24 (256개 IP)
- ap-northeast-2c: 10.0.4.0/24 (256개 IP)

특징:
- NAT Gateway를 통해서만 인터넷 접근
- 인터넷에서 직접 접근 불가 (보안)
- 내부 통신은 자유롭게 가능
```

**왜 별도 서브넷인가요?**
1. **보안**: 애플리케이션을 인터넷에서 직접 접근 차단
2. **제어**: 아웃바운드 트래픽만 허용 (업데이트, API 호출 등)
3. **모니터링**: 애플리케이션 트래픽을 별도로 추적

#### 4.2.3. Private DB Subnet (프라이빗 DB 서브넷)

**용도**: 데이터베이스 (Aurora MySQL)
**배치 리소스**: RDS Aurora 클러스터

```yaml
Private DB Subnet 구성:
- ap-northeast-2a: 10.0.5.0/24 (256개 IP)
- ap-northeast-2c: 10.0.6.0/24 (256개 IP)

특징:
- IPv4 인터넷 접근 완전 차단
- IPv6 아웃바운드만 허용 (패치, 모니터링용)
- 가장 높은 보안 수준
```

**왜 가장 안쪽에 배치하나요?**
1. **데이터 보호**: 가장 중요한 데이터 저장
2. **최소 권한**: 필요한 통신만 허용
3. **규정 준수**: 보안 규정 요구사항 충족

### 4.3. 서브넷 배치 전략

```
인터넷 (Internet)
    ↓
┌─────────────────────────────────────┐
│ Public Subnet (10.0.1.0/24, 10.0.2.0/24)
│ - ALB (로드밸런서)                    │
│ - NAT Gateway                       │
└─────────────────────────────────────┘
    ↓
┌─────────────────────────────────────┐
│ Private App Subnet (10.0.3.0/24, 10.0.4.0/24)
│ - ECS Fargate 컨테이너               │
│ - 애플리케이션 서버                    │
└─────────────────────────────────────┘
    ↓
┌─────────────────────────────────────┐
│ Private DB Subnet (10.0.5.0/24, 10.0.6.0/24)
│ - Aurora MySQL 클러스터               │
│ - 데이터베이스                         │
└─────────────────────────────────────┘
```

---

## 5. 라우팅 테이블

### 5.1. 라우팅 테이블이란?

라우팅 테이블은 네트워크 트래픽이 어디로 가야 하는지 알려주는 "교통 표지판"입니다.

**구성 요소**:
- **목적지 (Destination)**: 어디로 가고 싶은가?
- **타겟 (Target)**: 어떤 경로로 갈 것인가?

### 5.2. Public Route Table (퍼블릭 라우팅 테이블)

```yaml
Public Route Table:
목적지              타겟                설명
10.0.0.0/16        local              VPC 내부 통신
0.0.0.0/0          igw-xxxxx          모든 인터넷 트래픽
::/0               igw-xxxxx          모든 IPv6 인터넷 트래픽
```

**동작 원리**:
1. 목적지가 10.0.x.x → VPC 내부로 직접 전송
2. 목적지가 그 외 → 인터넷 게이트웨이로 전송

### 5.3. Private App Route Table (프라이빗 앱 라우팅 테이블)

```yaml
Private App Route Table (AZ-a):
목적지              타겟                설명
10.0.0.0/16        local              VPC 내부 통신
0.0.0.0/0          nat-xxxxx-a        인터넷 트래픽 (NAT Gateway)
::/0               eigw-xxxxx         IPv6 아웃바운드 전용

Private App Route Table (AZ-c):
목적지              타겟                설명
10.0.0.0/16        local              VPC 내부 통신
0.0.0.0/0          nat-xxxxx-c        인터넷 트래픽 (NAT Gateway)
::/0               eigw-xxxxx         IPv6 아웃바운드 전용
```

**왜 AZ별로 다른 라우팅 테이블인가요?**
1. **고가용성**: 각 AZ의 NAT Gateway 사용
2. **성능**: 같은 AZ 내에서 트래픽 처리
3. **비용**: Cross-AZ 트래픽 비용 절약

### 5.4. Private DB Route Table (프라이빗 DB 라우팅 테이블)

```yaml
Private DB Route Table:
목적지              타겟                설명
10.0.0.0/16        local              VPC 내부 통신만
::/0               eigw-xxxxx         IPv6 아웃바운드만 (관리 트래픽용)
```

**IPv6 아웃바운드가 필요한 이유:**
1. **보안 패치**: MySQL/Aurora 엔진 보안 업데이트 다운로드
2. **모니터링**: CloudWatch로 성능 메트릭 및 로그 전송
3. **백업**: S3로 자동 백업 및 스냅샷 업로드
4. **라이선스**: AWS 라이선스 서버와 인증 통신
5. **헬스체크**: AWS 관리 서비스와의 상태 확인

**보안 특징:**
- **IPv4 인터넷 경로 없음**: 0.0.0.0/0 경로가 없어서 IPv4로는 인터넷 접근 불가
- **아웃바운드만 허용**: 데이터베이스에서 시작하는 연결만 가능
- **인바운드 완전 차단**: 인터넷에서 데이터베이스로 직접 접근 불가능
- **VPC 내부 통신**: 애플리케이션과의 통신은 VPC 내부에서만

---

## 6. 게이트웨이

### 6.1. Internet Gateway (IGW)

#### 역할
인터넷과 VPC를 연결하는 관문입니다. 양방향 통신이 가능합니다.

#### 동작 원리
```
사용자 브라우저 → 인터넷 → IGW → ALB → 애플리케이션
애플리케이션 → ALB → IGW → 인터넷 → 외부 API
```

#### 특징
- VPC당 하나만 연결 가능
- 고가용성 (AWS가 자동 관리)
- 무료 (데이터 전송 비용만 발생)

### 6.2. NAT Gateway

#### 역할
프라이빗 서브넷의 리소스가 인터넷에 아웃바운드 연결을 할 수 있게 해줍니다.

#### 동작 원리
```
ECS 컨테이너 → NAT Gateway → IGW → 인터넷 → 외부 서비스
외부 서비스 ← NAT Gateway ← IGW ← 인터넷 (응답만)
```

#### 왜 필요한가요?
1. **보안**: 인바운드 연결 차단, 아웃바운드만 허용
2. **업데이트**: 패키지 업데이트, 보안 패치
3. **API 호출**: 외부 서비스와 통신

#### 고가용성 설계
```yaml
NAT Gateway 배치:
- ap-northeast-2a: Public Subnet에 NAT-A
- ap-northeast-2c: Public Subnet에 NAT-C

장점:
- 한 AZ 장애 시에도 다른 AZ는 정상 동작
- 각 AZ의 프라이빗 서브넷이 같은 AZ의 NAT 사용
```

### 6.3. Egress-only Internet Gateway (EIGW)

#### 역할
IPv6 전용 아웃바운드 게이트웨이입니다.

#### 특징
- IPv6 트래픽만 처리
- 아웃바운드 전용 (인바운드 차단)
- NAT Gateway보다 저렴

#### 사용 이유
```yaml
IPv6의 장점:
- NAT 불필요 (주소 공간 충분)
- 성능 향상
- 미래 대비

보안 유지:
- 아웃바운드만 허용
- 인바운드 연결 차단
```

---

## 7. 트래픽 흐름 분석

### 7.1. 사용자 요청 흐름 (인바운드)

#### Step 1: 사용자 → ALB
```
사용자 브라우저
    ↓ (HTTPS 요청)
인터넷
    ↓
Internet Gateway
    ↓
Public Subnet의 ALB
```

#### Step 2: ALB → ECS 컨테이너
```
ALB (Public Subnet)
    ↓ (내부 네트워크)
Private App Subnet의 ECS 컨테이너
```

#### Step 3: ECS → 데이터베이스
```
ECS 컨테이너 (Private App Subnet)
    ↓ (SQL 쿼리)
Aurora DB (Private DB Subnet)
```

#### Step 4: 응답 흐름
```
Aurora DB → ECS 컨테이너 → ALB → IGW → 인터넷 → 사용자
```

### 7.2. 컨테이너 업데이트 흐름 (아웃바운드)

#### Docker 이미지 Pull
```
ECS 컨테이너 (Private App Subnet)
    ↓
NAT Gateway (Public Subnet)
    ↓
Internet Gateway
    ↓
인터넷 (Amazon ECR)
```

#### 패키지 업데이트
```
ECS 컨테이너
    ↓ (apt update)
NAT Gateway
    ↓
IGW
    ↓
Ubuntu 패키지 저장소
```

### 7.3. 데이터베이스 관리 트래픽 흐름 (IPv6)

#### 데이터베이스가 인터넷에 접근해야 하는 이유들

**1. 보안 패치 및 업데이트**
```
Aurora DB → EIGW → 인터넷 → AWS 패치 서버
- MySQL 엔진 보안 패치 다운로드
- Aurora 엔진 업데이트
- 운영체제 보안 업데이트
```

**2. 모니터링 및 메트릭 전송**
```
Aurora DB → EIGW → 인터넷 → AWS CloudWatch
- 성능 메트릭 전송
- 로그 데이터 업로드
- 헬스체크 정보 전송
```

**3. 백업 및 스냅샷**
```
Aurora DB → EIGW → 인터넷 → AWS S3
- 자동 백업 데이터 업로드
- 스냅샷 저장
- Point-in-Time Recovery 데이터
```

**4. 라이선스 및 인증**
```
Aurora DB → EIGW → 인터넷 → AWS 라이선스 서버
- MySQL 라이선스 확인
- Aurora 기능 인증
- 사용량 보고
```

#### 왜 IPv6 + EIGW를 사용하나요?

**보안상의 이유:**
- **아웃바운드만 허용**: 데이터베이스에서 외부로 나가는 연결만 가능
- **인바운드 차단**: 인터넷에서 데이터베이스로 직접 접근 완전 차단
- **상태 기반 연결**: 데이터베이스가 시작한 연결의 응답만 허용

**비용상의 이유:**
- **NAT Gateway 불필요**: IPv6는 NAT 없이 직접 라우팅
- **데이터 전송 비용 절약**: NAT Gateway 데이터 처리 비용 없음
- **시간당 비용 절약**: EIGW는 NAT Gateway보다 저렴

**성능상의 이유:**
- **직접 라우팅**: NAT 변환 과정 없어서 더 빠름
- **대역폭 제한 없음**: NAT Gateway의 대역폭 제한 없음

---

## 8. 보안 설계

### 8.1. 계층별 보안 (Defense in Depth)

```
┌─────────────────────────────────────┐
│ 인터넷 (공격자)                        │
└─────────────────────────────────────┘
    ↓ (HTTPS만 허용)
┌─────────────────────────────────────┐
│ Public Subnet                       │
│ - ALB Security Group                │
│ - 80, 443 포트만 허용                 │
└─────────────────────────────────────┘
    ↓ (ALB에서 ECS로만)
┌─────────────────────────────────────┐
│ Private App Subnet                  │
│ - ECS Security Group                │
│ - ALB에서 8080 포트만 허용             │
└─────────────────────────────────────┘
    ↓ (ECS에서 DB로만)
┌─────────────────────────────────────┐
│ Private DB Subnet                   │
│ - Aurora Security Group             │
│ - ECS에서 3306 포트만 허용             │
└─────────────────────────────────────┘
```

### 8.2. Security Group 규칙

#### ALB Security Group
```yaml
인바운드 규칙:
- HTTP (80): 0.0.0.0/0 → ALB
- HTTPS (443): 0.0.0.0/0 → ALB

아웃바운드 규칙:
- 8080: ALB → ECS Security Group
```

#### ECS Security Group
```yaml
인바운드 규칙:
- 8080: ALB Security Group → ECS

아웃바운드 규칙:
- 3306: ECS → Aurora Security Group
- 443: ECS → 0.0.0.0/0 (HTTPS 아웃바운드)
```

#### Aurora Security Group
```yaml
인바운드 규칙:
- 3306: ECS Security Group → Aurora

아웃바운드 규칙:
- 없음 (필요시에만 추가)
```

### 8.3. Network ACL (추가 보안 계층)

Network ACL은 서브넷 수준의 방화벽입니다. Security Group과 달리 상태 비저장(stateless)이므로 인바운드와 아웃바운드 규칙을 모두 명시해야 합니다.

#### Public Subnet NACL
```yaml
인바운드 규칙:
- 80 (HTTP): 0.0.0.0/0 → ALB
- 443 (HTTPS): 0.0.0.0/0 → ALB  
- 32768-65535: VPC CIDR → 응답 트래픽 (AWS 권장 에페메랄 포트)

아웃바운드 규칙:
- 모든 트래픽: ALB → App, NAT Gateway 기능
```

#### Private App Subnet NACL
```yaml
인바운드 규칙:
- 8080: VPC CIDR → ECS 서비스 (ALB에서)
- 모든 포트: VPC CIDR → VPC 내부 통신
- 32768-65535: 0.0.0.0/0 → 외부 API 응답 (ECR Pull, 패키지 다운로드)

아웃바운드 규칙:
- 모든 트래픽: DB 접근, VPC Endpoint, NAT Gateway 통신
```

#### Private DB Subnet NACL
```yaml
인바운드 규칙:
- 3306 (MySQL): VPC CIDR → Aurora DB (ECS에서)
- 모든 포트: VPC CIDR → VPC 내부 관리 트래픽
- 32768-65535: 0.0.0.0/0 → IPv6 EIGW 응답 (패치, 업데이트)

아웃바운드 규칙:
- 32768-65535: VPC CIDR → App 서버로의 응답만 (최소 권한)
```

#### AWS 권장 에페메랄 포트 범위 (32768-65535)
**왜 이 범위를 사용하나요?**
- **Linux 기본값**: 대부분의 Linux 시스템에서 사용하는 동적 포트 범위
- **AWS 권장사항**: AWS 문서에서 공식 권장하는 범위
- **보안성**: 1024-65535보다 더 제한적이어서 보안상 유리
- **호환성**: ECS Fargate, ALB 등 AWS 서비스와 최적 호환

---

## 9. 고가용성 설계

### 9.1. Multi-AZ 배치

#### 리소스 분산
```yaml
ap-northeast-2a:
- Public Subnet: ALB, NAT Gateway
- Private App Subnet: ECS 태스크 50%
- Private DB Subnet: Aurora Writer

ap-northeast-2c:
- Public Subnet: ALB, NAT Gateway
- Private App Subnet: ECS 태스크 50%
- Private DB Subnet: Aurora Reader
```

#### 장애 시나리오

**시나리오 1: AZ-a 전체 장애**
```
결과:
- ALB는 AZ-c의 ECS 태스크로만 트래픽 전송
- Aurora는 AZ-c의 Reader가 Writer로 승격
- 서비스 계속 운영 (성능 저하 있을 수 있음)
```

**시나리오 2: NAT Gateway 장애**
```
AZ-a NAT Gateway 장애:
- AZ-a의 ECS 태스크: 인터넷 접근 불가
- AZ-c의 ECS 태스크: 정상 동작
- 새 배포 시 AZ-c에만 배치
```

### 9.2. 자동 복구 메커니즘

#### ECS Auto Scaling
```yaml
설정:
- 최소 태스크: 2개 (각 AZ에 1개씩)
- 최대 태스크: 4개
- 타겟 CPU: 70%

장애 시:
- 태스크 종료 → 자동으로 새 태스크 시작
- AZ 장애 → 정상 AZ에 추가 태스크 시작
```

#### Aurora 자동 Failover
```yaml
설정:
- Writer 1개, Reader 1개
- 자동 백업 활성화
- Multi-AZ 배치

장애 시:
- Writer 장애 → Reader가 Writer로 승격 (30초 이내)
- 새 Reader 자동 생성
```

---

## 10. 실제 구현 코드

### 10.1. Terraform 코드 구조

#### VPC 생성
```hcl
resource "aws_vpc" "this" {
  cidr_block                       = "10.0.0.0/16"
  enable_dns_support               = true
  enable_dns_hostnames             = true
  assign_generated_ipv6_cidr_block = true

  tags = {
    Name = "petclinic-dev-vpc"
    Environment = "dev"
  }
}
```

#### 서브넷 생성 (동적)
```hcl
# Public 서브넷
resource "aws_subnet" "public" {
  for_each = {
    "0" = { cidr = "10.0.1.0/24", az = "ap-northeast-2a" }
    "1" = { cidr = "10.0.2.0/24", az = "ap-northeast-2c" }
  }

  vpc_id                          = aws_vpc.this.id
  cidr_block                      = each.value.cidr
  availability_zone               = each.value.az
  map_public_ip_on_launch         = true

  tags = {
    Name = "petclinic-dev-public-${substr(each.value.az, -1, 1)}"
    Tier = "public"
  }
}
```

### 10.2. 라우팅 테이블 구성

#### Public 라우팅 테이블
```hcl
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.this.id
  }

  tags = {
    Name = "petclinic-dev-public-rt"
  }
}
```

#### Private App 라우팅 테이블
```hcl
resource "aws_route_table" "private_app" {
  for_each = aws_subnet.private_app
  vpc_id   = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[each.key].id
  }

  route {
    ipv6_cidr_block        = "::/0"
    egress_only_gateway_id = aws_egress_only_internet_gateway.this[0].id
  }

  tags = {
    Name = "petclinic-dev-private-app-${each.key}-rt"
  }
}
```

### 10.3. 보안 그룹 예시

#### ALB Security Group
```hcl
resource "aws_security_group" "alb" {
  name_prefix = "petclinic-alb-"
  vpc_id      = aws_vpc.this.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }
}
```

---

## 결론

이 네트워크 아키텍처는 다음과 같은 특징을 가집니다:

### 장점
1. **보안**: 계층별 격리로 최고 수준의 보안
2. **고가용성**: Multi-AZ 배치로 장애 대응
3. **확장성**: IPv6 지원으로 미래 대비
4. **비용 효율성**: 필요한 리소스만 생성

### 모니터링 포인트
1. **NAT Gateway 비용**: 데이터 전송량 모니터링
2. **Cross-AZ 트래픽**: AZ 간 통신 최소화
3. **보안 그룹 규칙**: 정기적인 보안 검토

### 향후 개선 방안
1. **VPC Endpoints**: AWS 서비스 접근 시 NAT Gateway 우회
2. **Transit Gateway**: 여러 VPC 연결 시 고려
3. **Network Load Balancer**: TCP 트래픽 처리 시 고려

이 문서를 통해 AWS VPC 네트워크의 동작 원리를 이해하고, 실제 운영 환경에서 안정적인 네트워크 인프라를 구축할 수 있습니다.