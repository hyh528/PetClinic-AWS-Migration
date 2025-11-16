#!/usr/bin/env pwsh
# =============================================================================
# Terraform Layer Plan Script (PowerShell)
# =============================================================================
# 목적: 단일 레이어에 대해 plan을 실행하고 결과를 저장
# 사용법: .\plan-layer.ps1 -Layer <layer-name> [-Environment <env>]
# 예시: .\plan-layer.ps1 -Layer 01-network -Environment dev

param(
    [Parameter(Mandatory = $true, HelpMessage = "Layer name (e.g., 01-network)")]
    [string]$Layer,

    [Parameter(HelpMessage = "Environment name (default: dev)")]
    [string]$Environment = "dev",

    [Parameter(HelpMessage = "Show help message")]
    [switch]$Help
)

# =============================================================================
# 설정 및 변수
# =============================================================================

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)
$LayersDir = Join-Path $ProjectRoot "layers"
$LayerDir = Join-Path $LayersDir $Layer
$EnvVarsFile = Join-Path $ProjectRoot "envs/${Environment}.tfvars"

# 색상 출력 함수
function Write-ColorOutput {
    param([string]$Message, [string]$Type = "Info")
    switch ($Type) {
        "Success" { Write-Host $Message -ForegroundColor Green }
        "Error" { Write-Host $Message -ForegroundColor Red }
        "Warning" { Write-Host $Message -ForegroundColor Yellow }
        "Info" { Write-Host $Message -ForegroundColor Cyan }
        default { Write-Host $Message -ForegroundColor White }
    }
}

# 도움말 표시 함수
function Show-Help {
    Write-Host @"
=============================================================================
Terraform Layer Plan Script (PowerShell)
=============================================================================

Usage:
    .\plan-layer.ps1 -Layer <layer-name> [-Environment <env>] [-Help]

Parameters:
    -Layer          Layer name (e.g., 01-network, 02-security)
    -Environment    Environment name (default: dev)
    -Help           Show this help message

Examples:
    .\plan-layer.ps1 -Layer 01-network
    .\plan-layer.ps1 -Layer 02-security -Environment staging

This script will:
1. Check if layer directory exists
2. Check if environment variables file exists
3. Run terraform plan with saved plan file
4. Display plan summary

=============================================================================
"@ -ForegroundColor Cyan
}

# =============================================================================
# 메인 로직
# =============================================================================

# 도움말 표시
if ($Help) {
    Show-Help
    exit 0
}

# 레이어 디렉터리 확인
if (-not (Test-Path $LayerDir)) {
    Write-ColorOutput "[ERROR] Layer directory not found: $LayerDir" "Error"
    exit 3
}

# 환경 변수 파일 확인
if (-not (Test-Path $EnvVarsFile)) {
    Write-ColorOutput "[ERROR] Environment variables file not found: $EnvVarsFile" "Error"
    exit 4
}

Write-ColorOutput "=============================================================================" "Info"
Write-ColorOutput "Planning Layer: $Layer (Environment: $Environment)" "Info"
Write-ColorOutput "=============================================================================" "Info"

# Plan 파일 경로
$PlanFile = Join-Path $LayerDir "tfplan"

# 백엔드 설정 구성 (init-layer.ps1과 동일한 방식)
$BackendCommon = Join-Path $ProjectRoot "backend.hcl"
$BackendConfigFile = Join-Path $LayerDir "backend.config"

$BackendArgs = @("-backend-config=$BackendCommon")

if (Test-Path $BackendConfigFile) {
    # backend.config 파일에서 key 추출 및 환경 접두사 정규화
    $content = Get-Content $BackendConfigFile -Raw
    if ($content -match 'key\s*=\s*"(?<raw>.+)"') {
        $raw = $Matches['raw']
        if ($raw -like '*/ *') {
            # 슬래시가 있으면 첫 번째 경로 세그먼트(환경)를 요청된 환경으로 교체
            $remainder = $raw -replace '^[^/]+/', ''
            $BackendArgs += "-backend-config=key=${Environment}/${remainder}"
        } else {
            # 슬래시가 없으면 환경 접두사 추가
            $BackendArgs += "-backend-config=key=${Environment}/${raw}"
        }
    } else {
        # key가 없으면 backend.config 파일 직접 사용
        $BackendArgs += "-backend-config=$BackendConfigFile"
    }
} else {
    # backend.config 파일이 없으면 기본 키 생성
    $BackendArgs += "-backend-config=key=${Environment}/${Layer}/terraform.tfstate"
}

# Terraform init -reconfigure 실행
Write-ColorOutput "[INFO] Reconfiguring backend for layer $Layer" "Info"
$InitArgs = @(
    "-chdir=$LayerDir",
    "init"
) + $BackendArgs + @(
    "-reconfigure",
    "-input=false"
)

& terraform @InitArgs
if ($LASTEXITCODE -ne 0) {
    Write-ColorOutput "[ERROR] Backend reconfiguration failed" "Error"
    exit 1
}

# Terraform plan 실행
Write-ColorOutput "[INFO] Running terraform plan for layer $Layer" "Info"
$PlanArgs = @(
    "-chdir=$LayerDir",
    "plan",
    "-var-file=../../envs/${Environment}.tfvars",
    "-out=tfplan",
    "-input=false"
)

Write-ColorOutput "[INFO] Running: terraform $($PlanArgs -join ' ')" "Info"

try {
    & terraform @PlanArgs
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "[SUCCESS] Plan completed successfully for layer $Layer" "Success"

        # Plan 파일 존재 확인 및 요약 표시
        if (Test-Path $PlanFile) {
            Write-ColorOutput "[INFO] Plan file saved: $PlanFile" "Info"

            # Plan 내용 요약 표시 (선택적)
            Write-ColorOutput "[INFO] To see detailed plan: terraform -chdir='$LayerDir' show tfplan" "Info"
            Write-ColorOutput "[INFO] To apply changes: terraform -chdir='$LayerDir' apply tfplan" "Info"
        }
    } elseif ($LASTEXITCODE -eq 2) {
        # Plan has changes (exit code 2)
        Write-ColorOutput "[WARNING] Plan completed with changes (exit code 2)" "Warning"
        Write-ColorOutput "[INFO] Plan file saved: $PlanFile" "Info"
        Write-ColorOutput "[INFO] To see detailed plan: terraform -chdir='$LayerDir' show tfplan" "Info"
        Write-ColorOutput "[INFO] To apply changes: terraform -chdir='$LayerDir' apply tfplan" "Info"
    } else {
        Write-ColorOutput "[ERROR] Plan failed for layer $Layer (exit code: $LASTEXITCODE)" "Error"
        exit 1
    }
} catch {
    Write-ColorOutput "[ERROR] Exception during plan: $($_.Exception.Message)" "Error"
    exit 1
}

# 완료 메시지
Write-ColorOutput "" "Info"
Write-ColorOutput "=============================================================================" "Success"
Write-ColorOutput "Layer $Layer plan completed successfully!" "Success"
Write-ColorOutput "=============================================================================" "Success"