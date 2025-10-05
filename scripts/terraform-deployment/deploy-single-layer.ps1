# ==========================================
# Terraform 개별 레이어 배포 스크립트 (PowerShell)
# ==========================================
# 목적: 특정 레이어만 배포하기 위한 스크립트
# 작성자: 영현
# 날짜: 2025-10-05

param(
    [Parameter(Mandatory=$true)]
    [string]$Layer,
    [switch]$AutoApprove = $false,
    [string]$Profile = "petclinic-yeonghyeon"
)

# 색상 함수들
function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Write-Header {
    param([string]$Message)
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host $Message -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
}

# 변수 설정
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)
$BaseDir = Join-Path $ProjectRoot "terraform\envs\dev"
$LayerDir = Join-Path $BaseDir $Layer

# 유효한 레이어 목록
$ValidLayers = @(
    "network", "security", "database", "parameter-store", "cloud-map",
    "lambda-genai", "application", "api-gateway", "monitoring", 
    "aws-native", "state-management"
)

# 레이어 설명
$LayerDescriptions = @{
    "network" = "기반 네트워크 인프라 (VPC, 서브넷, 게이트웨이)"
    "security" = "보안 설정 (보안 그룹, IAM, VPC 엔드포인트)"
    "database" = "데이터베이스 (Aurora MySQL 클러스터)"
    "parameter-store" = "설정 관리 (Systems Manager Parameter Store)"
    "cloud-map" = "서비스 디스커버리 (AWS Cloud Map)"
    "lambda-genai" = "AI 서비스 (Lambda + Bedrock)"
    "application" = "애플리케이션 (ECS, ALB, ECR)"
    "api-gateway" = "API 게이트웨이 (AWS API Gateway)"
    "monitoring" = "모니터링 (CloudWatch, 알람)"
    "aws-native" = "AWS 네이티브 서비스 통합 및 오케스트레이션"
    "state-management" = "상태 관리 유틸리티"
}

# 레이어 유효성 검사
if ($Layer -notin $ValidLayers) {
    Write-Error "유효하지 않은 레이어입니다: $Layer"
    Write-Host ""
    Write-Host "사용 가능한 레이어:" -ForegroundColor Yellow
    foreach ($validLayer in $ValidLayers) {
        Write-Host "  - $validLayer" -ForegroundColor White
    }
    Write-Host ""
    Write-Host "사용법: .\deploy-single-layer.ps1 -Layer <layer-name> [-AutoApprove]"
    exit 1
}

# 레이어 디렉토리 존재 확인
if (-not (Test-Path $LayerDir)) {
    Write-Error "레이어 디렉토리가 존재하지 않습니다: $LayerDir"
    exit 1
}

$StartTime = Get-Date
$Description = $LayerDescriptions[$Layer]

Write-Header "$Layer 레이어 배포"
Write-Host "설명: $Description"
Write-Host "경로: $LayerDir"
Write-Host "AWS 프로파일: $Profile"
Write-Host "시작 시간: $StartTime"
if ($AutoApprove) {
    Write-Host "모드: 자동 승인" -ForegroundColor Yellow
}
Write-Host ""

# 레이어 디렉토리로 이동
Push-Location $LayerDir

try {
    # 1. terraform init
    Write-Info "terraform init 실행 중..."
    $initResult = terraform init 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Success "terraform init 완료"
    } else {
        Write-Error "terraform init 실패"
        Write-Host $initResult -ForegroundColor Red
        exit 1
    }
    
    Write-Host ""
    
    # 2. terraform plan
    Write-Info "terraform plan 실행 중..."
    $planResult = terraform plan -out="tfplan" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Success "terraform plan 완료"
    } else {
        Write-Error "terraform plan 실패"
        Write-Host $planResult -ForegroundColor Red
        exit 1
    }
    
    Write-Host ""
    
    # 3. 사용자 확인 또는 자동 승인
    $shouldApply = $false
    
    if ($AutoApprove) {
        $shouldApply = $true
        Write-Info "자동 승인 모드로 apply 실행"
    } else {
        Write-Warning "위의 계획을 검토하고 계속 진행하시겠습니까?"
        $response = Read-Host "$Layer 레이어를 apply하시겠습니까? (y/n)"
        
        if ($response -eq 'y' -or $response -eq 'Y') {
            $shouldApply = $true
        } else {
            Write-Warning "$Layer 레이어 배포가 취소되었습니다."
            exit 0
        }
    }
    
    if ($shouldApply) {
        Write-Host ""
        
        # terraform apply 실행
        Write-Info "terraform apply 실행 중..."
        $applyStartTime = Get-Date
        
        $applyResult = terraform apply "tfplan" 2>&1
        if ($LASTEXITCODE -eq 0) {
            $applyEndTime = Get-Date
            $applyDuration = ($applyEndTime - $applyStartTime).TotalSeconds
            Write-Success "$Layer 레이어 배포 완료 (소요시간: $([math]::Round($applyDuration))초)"
            
            Write-Host ""
            Write-Info "배포된 리소스 확인 중..."
            terraform output
            
        } else {
            Write-Error "$Layer 레이어 배포 실패"
            Write-Host $applyResult -ForegroundColor Red
            exit 1
        }
    }
    
} catch {
    Write-Error "레이어 처리 중 예외 발생: $_"
    exit 1
} finally {
    # 계획 파일 정리
    if (Test-Path "tfplan") {
        Remove-Item "tfplan" -Force
    }
    
    # 원래 디렉토리로 돌아가기
    Pop-Location
}

# 종료 시간 및 통계
$EndTime = Get-Date
$TotalDuration = ($EndTime - $StartTime).TotalSeconds
$TotalMinutes = [math]::Floor($TotalDuration / 60)
$TotalSeconds = [math]::Round($TotalDuration % 60)

Write-Host ""
Write-Header "배포 완료"
Write-Host "레이어: $Layer"
Write-Host "상태: 성공" -ForegroundColor Green
Write-Host "총 소요시간: $TotalMinutes분 $TotalSeconds초"
Write-Host "완료 시간: $EndTime"
Write-Host ""

Write-Success "🎉 $Layer 레이어가 성공적으로 배포되었습니다!"
Write-Host ""
Write-Host "다음 단계:" -ForegroundColor Cyan
Write-Host "1. AWS 콘솔에서 생성된 리소스 확인"
Write-Host "2. 의존성이 있는 다음 레이어 배포 고려"
Write-Host "3. 애플리케이션 테스트 (해당하는 경우)"

exit 0