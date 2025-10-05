# ==========================================
# Terraform 전체 레이어 순차 배포 스크립트 (PowerShell)
# ==========================================
# 목적: 의존성을 고려하여 모든 레이어를 순서대로 배포
# 작성자: 영현
# 날짜: 2025-10-05

param(
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

# 레이어 실행 순서 (의존성 고려)
$Layers = @(
    "network",
    "security", 
    "database",
    "parameter-store",
    "cloud-map",
    "lambda-genai",
    "application",
    "api-gateway",
    "monitoring",
    "aws-native",
    "state-management"
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

# 실행 통계
$TotalLayers = $Layers.Count
$SuccessfulLayers = 0
$FailedLayers = 0
$SkippedLayers = 0

# 시작 시간 기록
$StartTime = Get-Date

Write-Header "Terraform 전체 레이어 배포 시작"
Write-Host "프로젝트 루트: $ProjectRoot"
Write-Host "대상 환경: dev"
Write-Host "총 레이어 수: $TotalLayers"
Write-Host "AWS 프로파일: $Profile"
Write-Host "시작 시간: $StartTime"
if ($AutoApprove) {
    Write-Host "모드: 자동 승인" -ForegroundColor Yellow
}
Write-Host ""

# 사용자 확인
if (-not $AutoApprove) {
    $response = Read-Host "모든 레이어를 순차적으로 배포하시겠습니까? (y/n)"
    if ($response -ne 'y' -and $response -ne 'Y') {
        Write-Warning "배포가 취소되었습니다."
        exit 0
    }
}

Write-Host ""

# 각 레이어 순차 실행
for ($i = 0; $i -lt $Layers.Count; $i++) {
    $layer = $Layers[$i]
    $layerNum = $i + 1
    $layerDir = Join-Path $BaseDir $layer
    $description = $LayerDescriptions[$layer]
    
    Write-Header "[$layerNum/$TotalLayers] $layer 레이어 배포"
    Write-Host "설명: $description"
    Write-Host "경로: $layerDir"
    Write-Host ""
    
    # 레이어 디렉토리 존재 확인
    if (-not (Test-Path $layerDir)) {
        Write-Error "레이어 디렉토리가 존재하지 않습니다: $layerDir"
        $FailedLayers++
        continue
    }
    
    # 레이어 디렉토리로 이동
    Push-Location $layerDir
    
    try {
        # 1. terraform init
        Write-Info "terraform init 실행 중..."
        $initResult = terraform init 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Success "terraform init 완료"
        } else {
            Write-Error "terraform init 실패"
            Write-Host $initResult -ForegroundColor Red
            $FailedLayers++
            Pop-Location
            continue
        }
        
        # 2. terraform plan
        Write-Info "terraform plan 실행 중..."
        $planResult = terraform plan -out="tfplan" 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Success "terraform plan 완료"
        } else {
            Write-Error "terraform plan 실패"
            Write-Host $planResult -ForegroundColor Red
            $FailedLayers++
            Pop-Location
            continue
        }
        
        # 3. 사용자 확인 또는 자동 승인
        $shouldApply = $false
        
        if ($AutoApprove) {
            $shouldApply = $true
            Write-Info "자동 승인 모드로 apply 실행"
        } else {
            Write-Host ""
            Write-Warning "계획을 검토하고 계속 진행하시겠습니까?"
            $response = Read-Host "$layer 레이어를 apply하시겠습니까? (y/n/s[skip])"
            
            if ($response -eq 'y' -or $response -eq 'Y') {
                $shouldApply = $true
            } elseif ($response -eq 's' -or $response -eq 'S') {
                Write-Warning "$layer 레이어 건너뜀"
                $SkippedLayers++
            } else {
                Write-Warning "$layer 레이어 배포 취소됨"
                $SkippedLayers++
            }
        }
        
        if ($shouldApply) {
            # terraform apply 실행
            Write-Info "terraform apply 실행 중..."
            $layerStartTime = Get-Date
            
            $applyResult = terraform apply "tfplan" 2>&1
            if ($LASTEXITCODE -eq 0) {
                $layerEndTime = Get-Date
                $layerDuration = ($layerEndTime - $layerStartTime).TotalSeconds
                Write-Success "$layer 레이어 배포 완료 (소요시간: $([math]::Round($layerDuration))초)"
                $SuccessfulLayers++
            } else {
                Write-Error "$layer 레이어 배포 실패"
                Write-Host $applyResult -ForegroundColor Red
                $FailedLayers++
            }
        }
        
        # 계획 파일 정리
        if (Test-Path "tfplan") {
            Remove-Item "tfplan" -Force
        }
        
    } catch {
        Write-Error "레이어 처리 중 예외 발생: $_"
        $FailedLayers++
    } finally {
        # 원래 디렉토리로 돌아가기
        Pop-Location
    }
    
    Write-Host ""
    
    # 실패 시 계속 진행할지 확인
    if ($FailedLayers -gt 0 -and -not $AutoApprove) {
        $response = Read-Host "실패한 레이어가 있습니다. 계속 진행하시겠습니까? (y/n)"
        if ($response -ne 'y' -and $response -ne 'Y') {
            Write-Warning "배포가 중단되었습니다."
            break
        }
    }
}

# 종료 시간 및 통계
$EndTime = Get-Date
$TotalDuration = ($EndTime - $StartTime).TotalSeconds
$TotalMinutes = [math]::Floor($TotalDuration / 60)
$TotalSeconds = [math]::Round($TotalDuration % 60)

Write-Header "배포 완료 요약"
Write-Host "총 레이어 수: $TotalLayers"
Write-Host "성공한 레이어: $SuccessfulLayers"
Write-Host "실패한 레이어: $FailedLayers"
Write-Host "건너뛴 레이어: $SkippedLayers"
Write-Host "총 소요시간: $TotalMinutes분 $TotalSeconds초"
Write-Host "완료 시간: $EndTime"
Write-Host ""

if ($FailedLayers -eq 0) {
    Write-Success "🎉 모든 레이어가 성공적으로 배포되었습니다!"
    Write-Host ""
    Write-Host "다음 단계:" -ForegroundColor Cyan
    Write-Host "1. AWS 콘솔에서 리소스 확인"
    Write-Host "2. 애플리케이션 배포 및 테스트"
    Write-Host "3. 모니터링 대시보드 확인"
} else {
    Write-Error "❌ $FailedLayers개 레이어에서 오류가 발생했습니다."
    Write-Host ""
    Write-Host "문제 해결 방법:" -ForegroundColor Red
    Write-Host "1. 실패한 레이어의 로그 확인"
    Write-Host "2. AWS 콘솔에서 리소스 상태 확인"
    Write-Host "3. 의존성 리소스가 올바르게 생성되었는지 확인"
    Write-Host "4. 개별 레이어에서 terraform plan/apply 재실행"
}

Write-Host ""
Write-Header "배포 스크립트 종료"

# 종료 코드 설정
if ($FailedLayers -eq 0) {
    exit 0
} else {
    exit 1
}