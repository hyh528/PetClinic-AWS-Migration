#!/usr/bin/env pwsh
# =============================================================================
# Terraform 레이어별 초기화 스크립트 (업계 표준 Backend HCL 방식)
# =============================================================================

param(
    [Parameter(Mandatory = $true)]
    [string]$Environment,
    [Parameter(Mandatory = $true)]
    [string]$Layer,
    [switch]$Reconfigure
)

# 색상 출력 함수
function Write-ColorOutput {
    param([string]$Message, [string]$Type = "Info")
    switch ($Type) {
        "Success" { Write-Host $Message -ForegroundColor Green }
        "Error" { Write-Host $Message -ForegroundColor Red }
        "Warning" { Write-Host $Message -ForegroundColor Yellow }
        default { Write-Host $Message -ForegroundColor Cyan }
    }
}

Write-ColorOutput "[INFO] Terraform 레이어 초기화 시작..." "Info"
Write-ColorOutput "[INFO] Environment: $Environment" "Info"
Write-ColorOutput "[INFO] Layer: $Layer" "Info"

# 경로 설정
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$EnvDir = Join-Path $ProjectRoot "envs/$Environment"
$LayerDir = Join-Path $EnvDir $Layer
$LayerBackendFile = Join-Path $LayerDir "backend.tf"

# 디렉토리 존재 확인
if (-not (Test-Path $LayerDir)) {
    Write-ColorOutput "[ERROR] 레이어 디렉토리가 존재하지 않습니다: $LayerDir" "Error"
    exit 1
}

try {
    # 레이어 디렉토리로 이동
    Set-Location $LayerDir
    
    # Backend 템플릿 파일을 레이어에 복사
    $BackendTemplate = Join-Path $EnvDir "backend-template.tf"
    if (Test-Path $BackendTemplate) {
        Copy-Item $BackendTemplate $LayerBackendFile -Force
        Write-ColorOutput "[SUCCESS] Copied backend template to layer directory" "Success"
    }
    
    # Backend HCL 설정 파일 경로
    $BackendHcl = Join-Path $EnvDir "backend.hcl"
    
    # Backend 설정 (레이어별 상태 파일 키 지정)
    $StateKey = "$Environment/$Layer/terraform.tfstate"
    
    # Terraform 초기화 (업계 표준 방식)
    Write-ColorOutput "[INFO] Initializing Terraform with backend.hcl and state key: $StateKey" "Info"
    
    $InitArgs = @(
        "init"
        "-backend-config=$BackendHcl"
        "-backend-config=key=$StateKey"
    )
    
    if ($Reconfigure) {
        $InitArgs += "-reconfigure"
    }
    
    & terraform @InitArgs
    
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "[SUCCESS] Terraform initialization completed!" "Success"
    } else {
        Write-ColorOutput "[ERROR] Terraform initialization failed!" "Error"
        exit 1
    }
    
} catch {
    Write-ColorOutput "[ERROR] 스크립트 실행 중 오류 발생: $($_.Exception.Message)" "Error"
    exit 1
} finally {
    # 원래 디렉토리로 복귀
    Set-Location $ProjectRoot
}

Write-ColorOutput "[SUCCESS] Layer initialization completed!" "Success"