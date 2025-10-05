# 네트워크 연결성 테스트 스크립트 (PowerShell 버전)
# 영현님 스타일: 클린 코드 + 클린 아키텍처 + Well-Architected Framework
# 목적: 각 서브넷에서 의도된 대상으로의 연결성 테스트

param(
    [switch]$DryRun = $false
)

# 색상 정의 (클린 코드: 의미 있는 상수)
$Colors = @{
    Red    = "Red"
    Green  = "Green"
    Yellow = "Yellow"
    Blue   = "Blue"
}

# 로그 함수 (클린 코드: 단일 책임 원칙)
function Write-Info { param($Message) Write-Host "[INFO] $Message" -ForegroundColor $Colors.Blue }
function Write-Success { param($Message) Write-Host "[SUCCESS] $Message" -ForegroundColor $Colors.Green }
function Write-Warning { param($Message) Write-Host "[WARNING] $Message" -ForegroundColor $Colors.Yellow }
function Write-Error { param($Message) Write-Host "[ERROR] $Message" -ForegroundColor $Colors.Red }

# 전역 변수 (클린 코드: 의미 있는 이름)
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)
$TerraformDir = Join-Path $ProjectRoot "terraform"
$ResultsDir = Join-Path $ProjectRoot "terraform-validation-results"
$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$ResultsFile = Join-Path $ResultsDir "network-connectivity-ps-$Timestamp.json"

# 결과 저장 배열
$ValidationResults = @()

# 결과 디렉토리 생성
if (-not (Test-Path $ResultsDir)) {
    New-Item -ItemType Directory -Path $ResultsDir -Force | Out-Null
}

# JSON 결과 추가 함수 (클린 코드: 재사용 가능한 함수)
function Add-Result {
    param(
        [string]$TestType,
        [string]$Source,
        [string]$Destination,
        [string]$Status,
        [string]$Message,
        [string]$Details = ""
    )
    
    $result = @{
        timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
        test_type = $TestType
        source = $Source
        destination = $Destination
        status = $Status
        message = $Message
        details = $Details
    }
    
    $script:ValidationResults += $result
}

# AWS CLI 설치 확인 (Well-Architected: 운영 우수성)
function Test-AwsCli {
    Write-Info "AWS CLI 설치 확인 중..."
    
    if ($DryRun) {
        Write-Info "드라이런 모드: AWS CLI 검사 건너뜀"
        Add-Result "prerequisites" "system" "aws_cli" "INFO" "Dry run mode - AWS CLI check skipped" ""
        return $true
    }
    
    try {
        $null = aws --version
        if ($LASTEXITCODE -ne 0) {
            throw "AWS CLI not found"
        }
    }
    catch {
        Write-Error "AWS CLI가 설치되지 않았습니다."
        Add-Result "prerequisites" "system" "aws_cli" "FAIL" "AWS CLI not installed" ""
        return $false
    }
    
    # AWS 자격 증명 확인
    try {
        $accountInfo = aws sts get-caller-identity --output json 2>$null | ConvertFrom-Json
        if ($LASTEXITCODE -ne 0) {
            throw "AWS credentials not configured"
        }
        
        Write-Success "AWS CLI 설정 완료 (Account: $($accountInfo.Account))"
        Add-Result "prerequisites" "system" "aws_cli" "PASS" "AWS CLI configured" "Account: $($accountInfo.Account)"
        return $true
    }
    catch {
        Write-Error "AWS 자격 증명이 설정되지 않았습니다."
        Add-Result "prerequisites" "system" "aws_credentials" "FAIL" "AWS credentials not configured" ""
        return $false
    }
}

# VPC 정보 수집 (클린 아키텍처: 의존성 역전)
function Get-VpcInfo {
    Write-Info "VPC 정보 수집 중..."
    
    if ($DryRun) {
        Write-Info "드라이런 모드: 가상 VPC ID 사용"
        return "vpc-mock123456"
    }
    
    try {
        # VPC ID 찾기 (petclinic 태그 기반)
        $vpcInfo = aws ec2 describe-vpcs --filters "Name=tag:Project,Values=petclinic" --query "Vpcs[0].VpcId" --output text 2>$null
        
        if ($LASTEXITCODE -ne 0 -or $vpcInfo -eq "None" -or [string]::IsNullOrEmpty($vpcInfo)) {
            Write-Error "PetClinic VPC를 찾을 수 없습니다."
            Add-Result "vpc_discovery" "system" "vpc_id" "FAIL" "VPC not found" ""
            return $null
        }
        
        Write-Success "VPC 발견: $vpcInfo"
        Add-Result "vpc_discovery" "system" "vpc_id" "PASS" "VPC found" $vpcInfo
        return $vpcInfo
    }
    catch {
        Write-Error "VPC 정보 수집 실패: $($_.Exception.Message)"
        Add-Result "vpc_discovery" "system" "vpc_id" "FAIL" "VPC discovery failed" $_.Exception.Message
        return $null
    }
}

# 서브넷 정보 수집 (클린 코드: 명확한 함수명)
function Get-SubnetInfo {
    param([string]$VpcId)
    
    Write-Info "서브넷 정보 수집 중..."
    
    if ($DryRun) {
        Write-Info "드라이런 모드: 가상 서브넷 정보 사용"
        return @{
            PublicSubnets = @("subnet-public1", "subnet-public2")
            PrivateAppSubnets = @("subnet-app1", "subnet-app2")  
            PrivateDbSubnets = @("subnet-db1", "subnet-db2")
        }
    }
    
    try {
        # 서브넷 타입별 수집
        $publicSubnets = aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VpcId" "Name=tag:Tier,Values=public" --query "Subnets[].SubnetId" --output text 2>$null
        $privateAppSubnets = aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VpcId" "Name=tag:Tier,Values=private-app" --query "Subnets[].SubnetId" --output text 2>$null
        $privateDbSubnets = aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VpcId" "Name=tag:Tier,Values=private-db" --query "Subnets[].SubnetId" --output text 2>$null
        
        # 결과 검증 및 로깅
        $publicList = if ([string]::IsNullOrEmpty($publicSubnets)) { @() } else { $publicSubnets -split '\s+' }
        $appList = if ([string]::IsNullOrEmpty($privateAppSubnets)) { @() } else { $privateAppSubnets -split '\s+' }
        $dbList = if ([string]::IsNullOrEmpty($privateDbSubnets)) { @() } else { $privateDbSubnets -split '\s+' }
        
        if ($publicList.Count -eq 0) {
            Write-Warning "Public 서브넷을 찾을 수 없습니다."
            Add-Result "subnet_discovery" "vpc" "public_subnets" "WARNING" "No public subnets found" ""
        } else {
            Write-Success "Public 서브넷: $($publicList -join ', ')"
            Add-Result "subnet_discovery" "vpc" "public_subnets" "PASS" "Public subnets found" ($publicList -join ', ')
        }
        
        if ($appList.Count -eq 0) {
            Write-Warning "Private App 서브넷을 찾을 수 없습니다."
            Add-Result "subnet_discovery" "vpc" "private_app_subnets" "WARNING" "No private app subnets found" ""
        } else {
            Write-Success "Private App 서브넷: $($appList -join ', ')"
            Add-Result "subnet_discovery" "vpc" "private_app_subnets" "PASS" "Private app subnets found" ($appList -join ', ')
        }
        
        if ($dbList.Count -eq 0) {
            Write-Warning "Private DB 서브넷을 찾을 수 없습니다."
            Add-Result "subnet_discovery" "vpc" "private_db_subnets" "WARNING" "No private db subnets found" ""
        } else {
            Write-Success "Private DB 서브넷: $($dbList -join ', ')"
            Add-Result "subnet_discovery" "vpc" "private_db_subnets" "PASS" "Private db subnets found" ($dbList -join ', ')
        }
        
        return @{
            PublicSubnets = $publicList
            PrivateAppSubnets = $appList
            PrivateDbSubnets = $dbList
        }
    }
    catch {
        Write-Error "서브넷 정보 수집 실패: $($_.Exception.Message)"
        Add-Result "subnet_discovery" "vpc" "error" "FAIL" "Subnet discovery failed" $_.Exception.Message
        return @{
            PublicSubnets = @()
            PrivateAppSubnets = @()
            PrivateDbSubnets = @()
        }
    }
}

# 라우트 테이블 검증 (Well-Architected: 보안)
function Test-RouteTables {
    param([string]$VpcId)
    
    Write-Info "라우트 테이블 검증 중..."
    
    if ($DryRun) {
        Write-Info "드라이런 모드: 라우트 테이블 검증 시뮬레이션"
        Add-Result "route_validation" "public_subnet" "internet_gateway" "PASS" "IGW route simulation" "Dry run mode"
        Add-Result "route_validation" "private_app_subnet" "nat_gateway" "PASS" "NAT route simulation" "Dry run mode"
        Add-Result "route_validation" "private_db_subnet" "no_internet_route" "PASS" "No internet route simulation" "Dry run mode"
        return
    }
    
    try {
        # Public 라우트 테이블 확인
        $publicRt = aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VpcId" "Name=tag:Tier,Values=public" --query "RouteTables[0].RouteTableId" --output text 2>$null
        
        if ($publicRt -ne "None" -and -not [string]::IsNullOrEmpty($publicRt)) {
            # 인터넷 게이트웨이 경로 확인
            $igwRoute = aws ec2 describe-route-tables --route-table-ids $publicRt --query "RouteTables[0].Routes[?DestinationCidrBlock=='0.0.0.0/0'].GatewayId" --output text 2>$null
            
            if ($igwRoute -match "^igw-") {
                Write-Success "Public 라우트 테이블: 인터넷 게이트웨이 경로 확인"
                Add-Result "route_validation" "public_subnet" "internet_gateway" "PASS" "IGW route exists" $igwRoute
            } else {
                Write-Error "Public 라우트 테이블: 인터넷 게이트웨이 경로 없음"
                Add-Result "route_validation" "public_subnet" "internet_gateway" "FAIL" "No IGW route" ""
            }
        } else {
            Write-Error "Public 라우트 테이블을 찾을 수 없습니다."
            Add-Result "route_validation" "public_subnet" "route_table" "FAIL" "Public route table not found" ""
        }
        
        # Private App 라우트 테이블 확인
        $privateAppRt = aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VpcId" "Name=tag:Tier,Values=private-app" --query "RouteTables[0].RouteTableId" --output text 2>$null
        
        if ($privateAppRt -ne "None" -and -not [string]::IsNullOrEmpty($privateAppRt)) {
            # NAT 게이트웨이 경로 확인
            $natRoute = aws ec2 describe-route-tables --route-table-ids $privateAppRt --query "RouteTables[0].Routes[?DestinationCidrBlock=='0.0.0.0/0'].NatGatewayId" --output text 2>$null
            
            if ($natRoute -match "^nat-") {
                Write-Success "Private App 라우트 테이블: NAT 게이트웨이 경로 확인"
                Add-Result "route_validation" "private_app_subnet" "nat_gateway" "PASS" "NAT route exists" $natRoute
            } else {
                Write-Warning "Private App 라우트 테이블: NAT 게이트웨이 경로 없음"
                Add-Result "route_validation" "private_app_subnet" "nat_gateway" "WARNING" "No NAT route" ""
            }
        } else {
            Write-Error "Private App 라우트 테이블을 찾을 수 없습니다."
            Add-Result "route_validation" "private_app_subnet" "route_table" "FAIL" "Private app route table not found" ""
        }
        
        # Private DB 라우트 테이블 확인 (인터넷 경로가 없어야 함)
        $privateDbRt = aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VpcId" "Name=tag:Tier,Values=private-db" --query "RouteTables[0].RouteTableId" --output text 2>$null
        
        if ($privateDbRt -ne "None" -and -not [string]::IsNullOrEmpty($privateDbRt)) {
            # 인터넷 경로가 없는지 확인 (보안)
            $internetRoute = aws ec2 describe-route-tables --route-table-ids $privateDbRt --query "RouteTables[0].Routes[?DestinationCidrBlock=='0.0.0.0/0']" --output text 2>$null
            
            if ([string]::IsNullOrEmpty($internetRoute)) {
                Write-Success "Private DB 라우트 테이블: 인터넷 경로 없음 (보안 준수)"
                Add-Result "route_validation" "private_db_subnet" "no_internet_route" "PASS" "No internet route (secure)" ""
            } else {
                Write-Error "Private DB 라우트 테이블: 인터넷 경로 존재 (보안 위험)"
                Add-Result "route_validation" "private_db_subnet" "no_internet_route" "FAIL" "Internet route exists (security risk)" ""
            }
        } else {
            Write-Error "Private DB 라우트 테이블을 찾을 수 없습니다."
            Add-Result "route_validation" "private_db_subnet" "route_table" "FAIL" "Private db route table not found" ""
        }
    }
    catch {
        Write-Error "라우트 테이블 검증 실패: $($_.Exception.Message)"
        Add-Result "route_validation" "error" "validation" "FAIL" "Route table validation failed" $_.Exception.Message
    }
}

# 네트워크 연결성 테스트
function Test-NetworkConnectivity {
    param($SubnetInfo)
    
    Write-Info "네트워크 연결성 테스트 중..."
    
    # Public → Internet 테스트
    Test-PublicToInternet $SubnetInfo.PublicSubnets
    
    # Private App → Internet (아웃바운드만) 테스트  
    Test-PrivateAppToInternet $SubnetInfo.PrivateAppSubnets
    
    # Private DB 격리 테스트
    Test-PrivateDbIsolation $SubnetInfo.PrivateDbSubnets
    
    # VPC 내부 통신 테스트
    Test-InternalCommunication $SubnetInfo
}

# Public Subnet에서 인터넷 연결성 테스트
function Test-PublicToInternet {
    param([array]$PublicSubnets)
    
    Write-Info "Public Subnet to Internet connectivity test"
    
    if ($PublicSubnets.Count -eq 0) {
        Add-Result "connectivity_test" "public_subnet" "internet" "FAIL" "No public subnets found" ""
        return
    }
    
    if ($DryRun) {
        Write-Success "Public Subnet: 인터넷 연결성 시뮬레이션 통과"
        Add-Result "connectivity_test" "public_subnet" "internet" "PASS" "Internet connectivity simulation" "Dry run mode"
        return
    }
    
    $publicSubnet = $PublicSubnets[0]
    
    try {
        # 라우트 테이블에서 IGW 경로 확인
        $routeTable = aws ec2 describe-route-tables --filters "Name=association.subnet-id,Values=$publicSubnet" --query "RouteTables[0].RouteTableId" --output text 2>$null
        
        if ($routeTable -eq "None" -or [string]::IsNullOrEmpty($routeTable)) {
            Add-Result "connectivity_test" "public_subnet" "internet" "FAIL" "No route table associated" $publicSubnet
            return
        }
        
        # 0.0.0.0/0 → IGW 경로 확인
        $igwRoute = aws ec2 describe-route-tables --route-table-ids $routeTable --query "RouteTables[0].Routes[?DestinationCidrBlock=='0.0.0.0/0' && GatewayId!=null].GatewayId" --output text 2>$null
        
        if ($igwRoute -match "^igw-") {
            Write-Success "Public Subnet: 인터넷 게이트웨이 경로 확인됨"
            Add-Result "connectivity_test" "public_subnet" "internet" "PASS" "IGW route exists for internet access" "Route: $igwRoute"
        } else {
            Write-Error "Public Subnet: 인터넷 게이트웨이 경로 없음"
            Add-Result "connectivity_test" "public_subnet" "internet" "FAIL" "No IGW route for internet access" "Route table: $routeTable"
        }
    }
    catch {
        Write-Error "Public 서브넷 연결성 테스트 실패: $($_.Exception.Message)"
        Add-Result "connectivity_test" "public_subnet" "internet" "FAIL" "Connectivity test failed" $_.Exception.Message
    }
}

# Private App Subnet에서 인터넷 아웃바운드 테스트
function Test-PrivateAppToInternet {
    param([array]$PrivateAppSubnets)
    
    Write-Info "Private App Subnet to Internet (outbound) test"
    
    if ($PrivateAppSubnets.Count -eq 0) {
        Add-Result "connectivity_test" "private_app_subnet" "internet" "FAIL" "No private app subnets found" ""
        return
    }
    
    if ($DryRun) {
        Write-Success "Private App Subnet: 아웃바운드 인터넷 연결성 시뮬레이션 통과"
        Add-Result "connectivity_test" "private_app_subnet" "internet" "PASS" "Outbound internet connectivity simulation" "Dry run mode"
        return
    }
    
    $privateAppSubnet = $PrivateAppSubnets[0]
    
    try {
        # 라우트 테이블에서 NAT Gateway 경로 확인
        $routeTable = aws ec2 describe-route-tables --filters "Name=association.subnet-id,Values=$privateAppSubnet" --query "RouteTables[0].RouteTableId" --output text 2>$null
        
        if ($routeTable -eq "None" -or [string]::IsNullOrEmpty($routeTable)) {
            Add-Result "connectivity_test" "private_app_subnet" "internet" "FAIL" "No route table associated" $privateAppSubnet
            return
        }
        
        # 0.0.0.0/0 → NAT Gateway 경로 확인
        $natRoute = aws ec2 describe-route-tables --route-table-ids $routeTable --query "RouteTables[0].Routes[?DestinationCidrBlock=='0.0.0.0/0' && NatGatewayId!=null].NatGatewayId" --output text 2>$null
        
        if ($natRoute -match "^nat-") {
            Write-Success "Private App Subnet: NAT Gateway 경로 확인됨"
            Add-Result "connectivity_test" "private_app_subnet" "internet" "PASS" "NAT Gateway route exists for outbound internet" "Route: $natRoute"
        } else {
            Write-Error "Private App Subnet: NAT Gateway 경로 없음"
            Add-Result "connectivity_test" "private_app_subnet" "internet" "FAIL" "No NAT Gateway route for outbound internet" "Route table: $routeTable"
        }
    }
    catch {
        Write-Error "Private App 서브넷 연결성 테스트 실패: $($_.Exception.Message)"
        Add-Result "connectivity_test" "private_app_subnet" "internet" "FAIL" "Connectivity test failed" $_.Exception.Message
    }
}

# Private DB Subnet 격리 테스트
function Test-PrivateDbIsolation {
    param([array]$PrivateDbSubnets)
    
    Write-Info "Private DB Subnet isolation test (security validation)"
    
    if ($PrivateDbSubnets.Count -eq 0) {
        Add-Result "connectivity_test" "private_db_subnet" "isolation" "FAIL" "No private db subnets found" ""
        return
    }
    
    if ($DryRun) {
        Write-Success "Private DB Subnet: 격리 시뮬레이션 통과"
        Add-Result "connectivity_test" "private_db_subnet" "isolation" "PASS" "Isolation simulation" "Dry run mode"
        return
    }
    
    $privateDbSubnet = $PrivateDbSubnets[0]
    
    try {
        # 라우트 테이블 확인
        $routeTable = aws ec2 describe-route-tables --filters "Name=association.subnet-id,Values=$privateDbSubnet" --query "RouteTables[0].RouteTableId" --output text 2>$null
        
        if ($routeTable -eq "None" -or [string]::IsNullOrEmpty($routeTable)) {
            Add-Result "connectivity_test" "private_db_subnet" "isolation" "FAIL" "No route table associated" $privateDbSubnet
            return
        }
        
        # 인터넷 경로가 없는지 확인 (보안 요구사항)
        $internetRoutes = aws ec2 describe-route-tables --route-table-ids $routeTable --query "RouteTables[0].Routes[?DestinationCidrBlock=='0.0.0.0/0']" --output text 2>$null
        
        if ([string]::IsNullOrEmpty($internetRoutes)) {
            Write-Success "Private DB Subnet: 인터넷 경로 없음 (보안 준수)"
            Add-Result "connectivity_test" "private_db_subnet" "isolation" "PASS" "No internet routes (secure isolation)" "Route table: $routeTable"
        } else {
            Write-Error "Private DB Subnet: 인터넷 경로 존재 (보안 위험)"
            Add-Result "connectivity_test" "private_db_subnet" "isolation" "FAIL" "Internet routes exist (security risk)" "Routes: $internetRoutes"
        }
    }
    catch {
        Write-Error "Private DB 서브넷 격리 테스트 실패: $($_.Exception.Message)"
        Add-Result "connectivity_test" "private_db_subnet" "isolation" "FAIL" "Isolation test failed" $_.Exception.Message
    }
}

# VPC 내부 통신 테스트
function Test-InternalCommunication {
    param($SubnetInfo)
    
    Write-Info "VPC internal communication test"
    
    if ($SubnetInfo.PrivateAppSubnets.Count -gt 0 -and $SubnetInfo.PrivateDbSubnets.Count -gt 0) {
        if ($DryRun) {
            Write-Success "VPC 내부 통신: 시뮬레이션 통과"
            Add-Result "connectivity_test" "private_app_subnet" "private_db_subnet" "PASS" "Internal communication simulation" "Dry run mode"
            return
        }
        
        try {
            $appSubnet = $SubnetInfo.PrivateAppSubnets[0]
            $dbSubnet = $SubnetInfo.PrivateDbSubnets[0]
            
            # 같은 VPC 내부인지 확인
            $appVpc = aws ec2 describe-subnets --subnet-ids $appSubnet --query "Subnets[0].VpcId" --output text 2>$null
            $dbVpc = aws ec2 describe-subnets --subnet-ids $dbSubnet --query "Subnets[0].VpcId" --output text 2>$null
            
            if ($appVpc -eq $dbVpc) {
                Write-Success "Private App ↔ Private DB: 같은 VPC 내부 통신 가능"
                Add-Result "connectivity_test" "private_app_subnet" "private_db_subnet" "PASS" "Same VPC allows internal communication" "VPC: $appVpc"
            } else {
                Write-Error "Private App ↔ Private DB: 다른 VPC (통신 불가)"
                Add-Result "connectivity_test" "private_app_subnet" "private_db_subnet" "FAIL" "Different VPCs prevent communication" "App VPC: $appVpc, DB VPC: $dbVpc"
            }
        }
        catch {
            Write-Error "VPC 내부 통신 테스트 실패: $($_.Exception.Message)"
            Add-Result "connectivity_test" "internal_communication" "subnets" "FAIL" "Internal communication test failed" $_.Exception.Message
        }
    } else {
        Add-Result "connectivity_test" "internal_communication" "subnets" "WARNING" "Insufficient subnets for internal communication test" ""
    }
}

# 결과 저장
function Save-Results {
    Write-Info "검증 결과 저장 중..."
    
    # JSON 변환 및 저장
    $jsonResults = $ValidationResults | ConvertTo-Json -Depth 10
    $jsonResults | Out-File -FilePath $ResultsFile -Encoding UTF8
    
    # 요약 통계 생성
    $totalTests = $ValidationResults.Count
    $passedTests = ($ValidationResults | Where-Object { $_.status -eq "PASS" }).Count
    $failedTests = ($ValidationResults | Where-Object { $_.status -eq "FAIL" }).Count
    $warningTests = ($ValidationResults | Where-Object { $_.status -eq "WARNING" }).Count
    
    # 요약 리포트 생성
    $summaryFile = Join-Path $ResultsDir "network-connectivity-ps-summary-$Timestamp.txt"
    $summaryContent = @"
=== 네트워크 연결성 검증 요약 (PowerShell 버전) ===
검증 시간: $(Get-Date)
총 테스트: $totalTests
통과: $passedTests
실패: $failedTests
경고: $warningTests

상세 결과: $ResultsFile

=== 주요 발견 사항 ===
"@
    
    # 실패한 테스트 목록 추가
    if ($failedTests -gt 0) {
        $summaryContent += "`n`nFailed tests:`n"
        $failedResults = $ValidationResults | Where-Object { $_.status -eq "FAIL" }
        foreach ($result in $failedResults) {
            $summaryContent += "- $($result.source) → $($result.destination): $($result.message)`n"
        }
    }
    
    $summaryContent | Out-File -FilePath $summaryFile -Encoding UTF8
    
    Write-Success "검증 결과가 저장되었습니다: $ResultsFile"
    Write-Info "요약 리포트: $summaryFile"
    
    return $failedTests
}

# 메인 실행 함수
function Main {
    Write-Info "=== 네트워크 연결성 검증 시작 (PowerShell 버전) ==="
    Write-Info "프로젝트 루트: $ProjectRoot"
    Write-Info "결과 저장 위치: $ResultsDir"
    
    if ($DryRun) {
        Write-Info "드라이런 모드로 실행 중..."
    }
    
    # AWS CLI 확인
    if (-not (Test-AwsCli)) {
        Write-Error "AWS CLI 설정이 필요합니다."
        $failedCount = Save-Results
        exit 1
    }
    
    # VPC 정보 수집
    $vpcId = Get-VpcInfo
    if (-not $vpcId) {
        Write-Error "VPC 정보를 가져올 수 없습니다."
        $failedCount = Save-Results
        exit 1
    }
    
    # 서브넷 정보 수집
    $subnetInfo = Get-SubnetInfo $vpcId
    
    # 라우트 테이블 검증
    Test-RouteTables $vpcId
    
    # 네트워크 연결성 테스트
    Test-NetworkConnectivity $subnetInfo
    
    # 결과 저장
    $failedCount = Save-Results
    
    Write-Success "=== 네트워크 연결성 검증 완료 (PowerShell 버전) ==="
    
    # 실패한 테스트가 있으면 종료 코드 1 반환
    if ($failedCount -gt 0) {
        Write-Error "$failedCount tests failed."
        exit 1
    }
}

# 스크립트 실행
Main