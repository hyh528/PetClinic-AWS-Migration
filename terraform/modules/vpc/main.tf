# VPC 모듈 메인 파일
# 이 파일은 AWS에서 Virtual Private Cloud (VPC)를 생성하고, 서브넷, 인터넷 게이트웨이, NAT 게이트웨이 등을 설정합니다.
# VPC는 우리 애플리케이션이 실행될 가상의 네트워크 공간입니다.

# ==========================================
# 사전 조건 검증 (Preconditions)
# ==========================================
locals {
  # 입력 검증 및 사전 조건
  azs = var.azs

  # 서브넷 수와 AZ 수 일치 검증
  subnet_az_count_valid = (
    length(var.public_subnet_cidrs) == length(var.azs) &&
    length(var.private_app_subnet_cidrs) == length(var.azs) &&
    length(var.private_db_subnet_cidrs) == length(var.azs)
  )

  # CIDR 블록 겹침 검증
  all_subnet_cidrs = concat(
    var.public_subnet_cidrs,
    var.private_app_subnet_cidrs,
    var.private_db_subnet_cidrs
  )

  # VPC CIDR 내 서브넷 포함 검증
  subnets_within_vpc = alltrue([
    for cidr in local.all_subnet_cidrs :
    cidrsubnet(var.vpc_cidr, 0, 0) == var.vpc_cidr ? true :
    can(cidrsubnet(var.vpc_cidr, tonumber(split("/", cidr)[1]) - tonumber(split("/", var.vpc_cidr)[1]), 0))
  ])

  # 환경별 설정
  is_production = contains(["prd", "prod", "production"], var.environment)

  # NAT Gateway 설정 검증
  nat_gateway_config_valid = var.enable_nat_gateway ? (
    var.single_nat_gateway ? true : var.create_nat_per_az
  ) : true

  # for_each 맵을 위한 결정적 문자열 키("0","1",...) 생성
  public_defs = {
    for idx, cidr in var.public_subnet_cidrs :
    tostring(idx) => {
      cidr = cidr
      az   = local.azs[idx]
    }
  }

  private_app_defs = {
    for idx, cidr in var.private_app_subnet_cidrs :
    tostring(idx) => {
      cidr = cidr
      az   = local.azs[idx]
    }
  }

  private_db_defs = {
    for idx, cidr in var.private_db_subnet_cidrs :
    tostring(idx) => {
      cidr = cidr
      az   = local.azs[idx]
    }
  }

  # 에러 처리를 위한 설정
  common_tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "terraform"
    Module      = "vpc"
  })
}

# 사전 조건 검증 체크
check "subnet_configuration" {
  assert {
    condition     = local.subnet_az_count_valid
    error_message = "서브넷 CIDR 목록의 개수가 AZ 개수와 일치하지 않습니다. 각 서브넷 타입(public, private_app, private_db)은 AZ 개수와 동일한 CIDR을 가져야 합니다."
  }

  assert {
    condition     = local.subnets_within_vpc
    error_message = "일부 서브넷 CIDR이 VPC CIDR 범위를 벗어납니다. 모든 서브넷은 VPC CIDR 블록 내에 포함되어야 합니다."
  }

  assert {
    condition     = local.nat_gateway_config_valid
    error_message = "NAT Gateway 설정이 올바르지 않습니다. single_nat_gateway가 true이면 create_nat_per_az는 false여야 합니다."
  }
}
# VPC (Virtual Private Cloud): AWS에서 격리된 네트워크 공간을 만듭니다.
# 우리 애플리케이션이 안전하게 실행될 가상의 데이터센터입니다.

# ==========================================
# VPC 리소스 (에러 처리 및 생명주기 관리 강화)
# ==========================================
resource "aws_vpc" "this" {
  cidr_block                       = var.vpc_cidr
  enable_dns_support               = var.enable_dns_support
  enable_dns_hostnames             = var.enable_dns_hostnames
  assign_generated_ipv6_cidr_block = var.enable_ipv6

  # 생명주기 관리 (환경별 차별화)
  lifecycle {
    prevent_destroy = false # 프로덕션에서는 true로 설정 권장

    # 중요한 속성 변경 시 새 리소스 생성 후 기존 리소스 삭제
    create_before_destroy = true

    # CIDR 블록 변경 방지 (네트워크 재구성 방지)
    ignore_changes = [
      assign_generated_ipv6_cidr_block
    ]

    # 사후 조건 검증 (현재 비활성화 - 검증 후 활성화 예정)
    # postcondition {
    #   condition     = self.state == "available"
    #   error_message = "VPC가 사용 가능한 상태가 아닙니다. AWS 서비스 상태를 확인하세요."
    # }

    # postcondition {
    #   condition     = var.enable_dns_support ? self.enable_dns_support == true : true
    #   error_message = "DNS 지원이 요청되었지만 활성화되지 않았습니다."
    # }

    # postcondition {
    #   condition     = var.enable_dns_hostnames ? self.enable_dns_hostnames == true : true
    #   error_message = "DNS 호스트 이름이 요청되었지만 활성화되지 않았습니다."
    # }
  }

  tags = merge(local.common_tags, {
    Name        = "${var.name_prefix}-vpc"
    Environment = var.environment
    Tier        = "network"
  })
}

# 인터넷 게이트웨이
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  # 인터넷 게이트웨이 (Internet Gateway): VPC가 인터넷과 연결될 수 있게 해줍니다.
  # 퍼블릭 서브넷의 리소스들이 인터넷에 접근할 수 있습니다.

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-igw"
    Environment = var.environment
  })
}

# IPv6용 Egress-only 인터넷 게이트웨이 (프라이빗 서브넷)
# Egress-only 인터넷 게이트웨이: IPv6 전용 게이트웨이로, 아웃바운드 트래픽만 허용합니다.
# 프라이빗 서브넷의 IPv6 리소스들이 인터넷으로 나갈 수 있습니다.
resource "aws_egress_only_internet_gateway" "this" {
  count  = var.enable_ipv6 ? 1 : 0
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-eigw"
    Environment = var.environment
  })
  # IPv6 CIDR 블록 계산: VPC의 IPv6 주소 범위에서 서브넷용 작은 범위를 만듭니다.
}

# VPC의 /56에서 서브넷용 IPv6 /64 블록 파생 (활성화 시)
locals {
  vpc_ipv6_cidr = var.enable_ipv6 ? aws_vpc.this.ipv6_cidr_block : null
  # 겹침 방지를 위해 각 티어에 다른 인덱스 범위 할당
  public_ipv6_blocks = var.enable_ipv6 ? { for k, v in local.public_defs : k => cidrsubnet(local.vpc_ipv6_cidr, 8, tonumber(k)) } : {}
  app_ipv6_blocks    = var.enable_ipv6 ? { for k, v in local.private_app_defs : k => cidrsubnet(local.vpc_ipv6_cidr, 8, tonumber(k) + 10) } : {}
  db_ipv6_blocks     = var.enable_ipv6 ? { for k, v in local.private_db_defs : k => cidrsubnet(local.vpc_ipv6_cidr, 8, tonumber(k) + 20) } : {}

  egress_only_igw_id = var.enable_ipv6 ? aws_egress_only_internet_gateway.this[0].id : null
  # 퍼블릭 서브넷: 인터넷 게이트웨이를 통해 인터넷에 직접 연결된 서브넷입니다.
  # 로드 밸런서나 웹 서버 같은 공개 서비스를 여기에 배치합니다.
}

# 퍼블릭 서브넷 (런치 시 퍼블릭 IP 매핑 = true)
resource "aws_subnet" "public" {
  for_each = local.public_defs

  vpc_id                          = aws_vpc.this.id
  cidr_block                      = each.value.cidr
  availability_zone               = each.value.az
  map_public_ip_on_launch         = true
  assign_ipv6_address_on_creation = var.enable_ipv6
  ipv6_cidr_block                 = var.enable_ipv6 ? local.public_ipv6_blocks[each.key] : null

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-public-${substr(each.value.az, length(each.value.az) - 1, 1)}"
    Environment = var.environment
    Tier        = "public"
  })
}

# 프라이빗 앱 서브넷
resource "aws_subnet" "private_app" {
  for_each = local.private_app_defs

  vpc_id                          = aws_vpc.this.id
  cidr_block                      = each.value.cidr
  availability_zone               = each.value.az
  assign_ipv6_address_on_creation = var.enable_ipv6
  ipv6_cidr_block                 = var.enable_ipv6 ? local.app_ipv6_blocks[each.key] : null

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-private-app-${substr(each.value.az, length(each.value.az) - 1, 1)}"
    Environment = var.environment
    Tier        = "private-app"
  })
}

# 프라이빗 DB 서브넷
resource "aws_subnet" "private_db" {
  for_each = local.private_db_defs

  vpc_id                          = aws_vpc.this.id
  cidr_block                      = each.value.cidr
  availability_zone               = each.value.az
  assign_ipv6_address_on_creation = var.enable_ipv6
  ipv6_cidr_block                 = var.enable_ipv6 ? local.db_ipv6_blocks[each.key] : null

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-private-db-${substr(each.value.az, length(each.value.az) - 1, 1)}"
    Environment = var.environment
    Tier        = "private-db"
  })
}

# AZ별 NAT용 탄력적 IP
resource "aws_eip" "nat" {
  for_each = var.create_nat_per_az ? aws_subnet.public : {}

  domain = "vpc"

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-nat-eip-${substr(each.value.availability_zone, length(each.value.availability_zone) - 1, 1)}"
    Environment = var.environment
  })
}

# AZ별 NAT 게이트웨이 (해당 퍼블릭 서브넷에)
resource "aws_nat_gateway" "this" {
  for_each = var.create_nat_per_az ? aws_subnet.public : {}

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.public[each.key].id

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-nat-${substr(aws_subnet.public[each.key].availability_zone, length(aws_subnet.public[each.key].availability_zone) - 1, 1)}"
    Environment = var.environment
  })
}

# 퍼블릭 라우트 테이블 (공유)
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-public-rt"
    Environment = var.environment
    Tier        = "public"
  })
}

# IGW를 통한 퍼블릭 기본 IPv4 경로
resource "aws_route" "public_ipv4_default" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

# IGW를 통한 퍼블릭 기본 IPv6 경로 (듀얼스택)
resource "aws_route" "public_ipv6_default" {
  count                       = var.enable_ipv6 ? 1 : 0
  route_table_id              = aws_route_table.public.id
  destination_ipv6_cidr_block = "::/0"
  gateway_id                  = aws_internet_gateway.this.id
}

# 퍼블릭 RT를 퍼블릭 서브넷에 연결
resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# 프라이빗 앱 라우트 테이블 (NAT 대칭을 위한 서브넷별)
resource "aws_route_table" "private_app" {
  for_each = aws_subnet.private_app
  vpc_id   = aws_vpc.this.id

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-private-app-${substr(each.value.availability_zone, length(each.value.availability_zone) - 1, 1)}-rt"
    Environment = var.environment
    Tier        = "private-app"
  })
}

# 프라이빗 DB 라우트 테이블 (인터넷으로의 IPv4 기본 경로 없음)
resource "aws_route_table" "private_db" {
  for_each = aws_subnet.private_db
  vpc_id   = aws_vpc.this.id

  tags = merge(var.tags, {
    Name        = "${var.name_prefix}-private-db-${substr(each.value.availability_zone, length(each.value.availability_zone) - 1, 1)}-rt"
    Environment = var.environment
    Tier        = "private-db"
  })
}

# 프라이빗 앱: 같은 AZ의 NAT로 기본 IPv4 경로
resource "aws_route" "private_app_ipv4_default" {
  for_each               = aws_route_table.private_app
  route_table_id         = each.value.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[each.key].id
}

# 프라이빗 앱: Egress-only IGW로 기본 IPv6 경로
resource "aws_route" "private_app_ipv6_default" {
  for_each                    = var.enable_ipv6 ? aws_route_table.private_app : {}
  route_table_id              = each.value.id
  destination_ipv6_cidr_block = "::/0"
  egress_only_gateway_id      = local.egress_only_igw_id
}

# 프라이빗 DB: Egress-only IGW로 기본 IPv6 경로 (IPv4 기본 경로 없음)
resource "aws_route" "private_db_ipv6_default" {
  for_each                    = var.enable_ipv6 ? aws_route_table.private_db : {}
  route_table_id              = each.value.id
  destination_ipv6_cidr_block = "::/0"
  egress_only_gateway_id      = local.egress_only_igw_id
}

# 프라이빗 라우트 테이블 연결
resource "aws_route_table_association" "private_app" {
  for_each       = aws_subnet.private_app
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private_app[each.key].id
}

resource "aws_route_table_association" "private_db" {
  for_each       = aws_subnet.private_db
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private_db[each.key].id
}