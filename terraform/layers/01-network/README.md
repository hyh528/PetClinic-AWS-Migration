# Network Layer (01-network)

## 개요

AWS Well-Architected 네트워킹 원칙에 따른 기본 네트워크 인프라 레이어입니다. 모든 다른 레이어의 기반이 되는 VPC, 서브넷, 게이트웨이를 구성합니다.

## 의존성

### 필수 의존성
- **없음** (기반 레이어)

### 선택적 의존성
- **없음**

## 배포 단계

### 단일 단계 배포
```bash
# 배포
terraform apply -var-file=../../../envs/dev.tfvars
```

## 생성 리소스

### VPC 및 기본 네트워킹
- **VPC**: 10.0.0.0/16 (IPv4) + Amazon 제공 /56 (IPv6)
- **Internet Gateway**: 퍼블릭 서브넷 인터넷 접근용
- **Egress-only Internet Gateway**: 프라이빗 서브넷 IPv6 아웃바운드 전용
- **NAT Gateway**: 프라이빗 앱 서브넷 IPv4 아웃바운드 인터넷 접근

### 서브넷 구성
| 서브넷 유형 | AZ | CIDR | 용도 | 라우팅 |
|-------------|----|----- |------|--------|
| Public | ap-northeast-2a | 10.0.1.0/24 | ALB, NAT Gateway | IGW |
| Public | ap-northeast-2c | 10.0.2.0/24 | ALB, NAT Gateway | IGW |
| Private App | ap-northeast-2a | 10.0.3.0/24 | ECS Fargate | NAT Gateway |
| Private App | ap-northeast-2c | 10.0.4.0/24 | ECS Fargate | NAT Gateway |
| Private DB | ap-northeast-2a | 10.0.5.0/24 | Aurora MySQL | EIGW (IPv6만) |
| Private DB | ap-northeast-2c | 10.0.6.0/24 | Aurora MySQL | EIGW (IPv6만) |

### 라우팅 테이블
- **Public Route Table**: 0.0.0.0/0 → IGW, ::/0 → IGW
- **Private App Route Table**: 0.0.0.0/0 → NAT Gateway, ::/0 → EIGW
- **Private DB Route Table**: IPv4 기본(local만), ::/0 → EIGW

### VPC 엔드포인트
- **ECR API/DKR**: Docker 이미지 Pull
- **CloudWatch Logs**: 로그 전송
- **X-Ray**: 분산 추적 데이터 전송
- **Systems Manager**: Parameter Store 접근
- **Secrets Manager**: 민감 정보 접근
- **KMS**: 암호화 키 관리

## 아키텍처 설계 원칙

### AWS Well-Architected Framework 적용

#### 1. 보안 (Security)
- **네트워크 격리**: Public/Private/DB 서브넷 분리
- **최소 권한**: DB 서브넷은 인터넷 접근 차단 (IPv4)
- **VPC 엔드포인트**: AWS 서비스 안전 접근

#### 2. 안정성 (Reliability)
- **Multi-AZ 배포**: 2개 가용 영역 사용
- **중복성**: 각 AZ별 서브넷 구성
- **장애 격리**: AZ 장애 시 다른 AZ에서 서비스 지속

#### 3. 성능 효율성 (Performance Efficiency)
- **지역 최적화**: ap-northeast-2 (서울) 리전
- **네트워크 최적화**: VPC 엔드포인트로 AWS 서비스 직접 접근
- **대역폭 최적화**: NAT Gateway를 통한 효율적 아웃바운드

#### 4. 비용 최적화 (Cost Optimization)
- **NAT Gateway**: 각 AZ별 배치로 가용성과 비용 균형
- **VPC 엔드포인트**: 인터넷 게이트웨이 트래픽 비용 절감
- **Right-sizing**: 필요한 서브넷만 생성

#### 5. 지속 가능성 (Sustainability)
- **리소스 효율성**: 적절한 CIDR 블록 크기
- **트래픽 최적화**: VPC 엔드포인트로 불필요한 인터넷 트래픽 감소

## 네트워크 보안 설계

### 계층별 보안
```
Internet
    ↓
[Internet Gateway]
    ↓
Public Subnet (ALB, NAT Gateway)
    ↓
[NAT Gateway]
    ↓
Private App Subnet (ECS Fargate)
    ↓
[VPC 내부 통신만]
    ↓
Private DB Subnet (Aurora MySQL)
```

### 트래픽 흐름
- **인바운드**: Internet → IGW → Public Subnet → Private App Subnet
- **아웃바운드**: Private App Subnet → NAT Gateway → IGW → Internet
- **AWS 서비스**: Private Subnet → VPC Endpoint → AWS Services
- **DB 접근**: Private App Subnet → Private DB Subnet (VPC 내부만)

## 제공하는 출력값

```hcl
# 다른 레이어에서 참조 가능한 출력값
outputs = {
  # VPC 정보
  vpc_id   = "vpc-xxxxxxxxx"
  vpc_cidr = "10.0.0.0/16"
  
  # 서브넷 정보
  public_subnet_ids = {
    "ap-northeast-2a" = "subnet-xxxxxxxxx"
    "ap-northeast-2c" = "subnet-yyyyyyyyy"
  }
  
  private_app_subnet_ids = {
    "ap-northeast-2a" = "subnet-aaaaaaaaa"
    "ap-northeast-2c" = "subnet-bbbbbbbbb"
  }
  
  private_db_subnet_ids = {
    "ap-northeast-2a" = "subnet-ccccccccc"
    "ap-northeast-2c" = "subnet-ddddddddd"
  }
  
  # 게이트웨이 정보
  internet_gateway_id = "igw-xxxxxxxxx"
  nat_gateway_ids = {
    "ap-northeast-2a" = "nat-xxxxxxxxx"
    "ap-northeast-2c" = "nat-yyyyyyyyy"
  }
  
  # VPC 엔드포인트 정보
  vpc_endpoints = {
    ecr_api = "vpce-xxxxxxxxx"
    ecr_dkr = "vpce-yyyyyyyyy"
    logs    = "vpce-zzzzzzzzz"
    # ...
  }
}
```

## 다른 레이어에서 참조 방법

```hcl
# 다른 레이어의 data.tf에서
data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket  = var.tfstate_bucket_name
    key     = "envs/${var.environment}/01-network/terraform.tfstate"
    region  = var.aws_region
    profile = var.aws_profile
  }
}

# 사용 예시
resource "aws_security_group" "example" {
  vpc_id = data.terraform_remote_state.network.outputs.vpc_id
  
  ingress {
    cidr_blocks = [data.terraform_remote_state.network.outputs.vpc_cidr]
  }
}

resource "aws_instance" "example" {
  subnet_id = data.terraform_remote_state.network.outputs.private_app_subnet_ids["ap-northeast-2a"]
}
```

## 검증 방법

```bash
# VPC 확인
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=petclinic-dev-vpc"

# 서브넷 확인
aws ec2 describe-subnets --filters "Name=tag:Layer,Values=01-network"

# 라우팅 테이블 확인
aws ec2 describe-route-tables --filters "Name=tag:Layer,Values=01-network"

# NAT Gateway 확인
aws ec2 describe-nat-gateways --filter "Name=tag:Layer,Values=01-network"

# VPC 엔드포인트 확인
aws ec2 describe-vpc-endpoints --filters "Name=tag:Layer,Values=01-network"
```

## 주의사항

1. **기반 레이어**: 다른 모든 레이어가 이 레이어에 의존하므로 신중하게 변경
2. **CIDR 블록**: 변경 시 모든 서브넷 재생성 필요
3. **NAT Gateway**: 비용이 발생하므로 필요시에만 활성화
4. **VPC 엔드포인트**: 필요한 서비스만 생성하여 비용 최적화
5. **IPv6**: 듀얼스택 지원하지만 필요에 따라 비활성화 가능

## 확장 계획

### Phase 2 확장 가능 항목
- **추가 AZ**: ap-northeast-2d 추가 (3-AZ 구성)
- **Transit Gateway**: 다른 VPC와 연결
- **VPC Peering**: 다른 환경과 연결
- **Direct Connect**: 온프레미스 연결
- **추가 VPC 엔드포인트**: 새로운 AWS 서비스 사용 시

### 모니터링 확장
- **VPC Flow Logs**: 네트워크 트래픽 분석
- **CloudWatch 네트워크 메트릭**: 대역폭 모니터링
- **AWS Config**: 네트워크 구성 변경 추적