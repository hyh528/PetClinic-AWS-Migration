#!/usr/bin/env pwsh
# =============================================================================
# Terraform Layer Apply Script (PowerShell)
# =============================================================================
# 목적: 단일 레이어에 대해 apply를 실행하고 결과를 확인
# 사용법: .\apply-layer.ps1 -Layer <layer-name> [-Environment <env>] [-AutoApprove]
# 예시: .\apply-layer.ps1 -Layer 01-network -Environment dev -AutoApprove

param(
    [Parameter(Mandatory = $true, HelpMessage = "Layer name (e.g., 01-network)")]
    [string]$Layer,

    [Parameter(HelpMessage = "Environment name (default: dev)")]
    [string]$Environment = "dev",

    [Parameter(HelpMessage = "Auto approve apply without confirmation")]
    [switch]$AutoApprove,

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
Terraform Layer Apply Script (PowerShell)
=============================================================================

Usage:
    .\apply-layer.ps1 -Layer <layer-name> [-Environment <env>] [-AutoApprove] [-Help]

Parameters:
    -Layer          Layer name (e.g., 01-network, 02-security)
    -Environment    Environment name (default: dev)
    -AutoApprove    Auto approve apply without confirmation
    -Help           Show this help message

Examples:
    .\apply-layer.ps1 -Layer 01-network
    .\apply-layer.ps1 -Layer 02-security -Environment staging -AutoApprove

This script will:
1. Check if layer directory exists
2. Check if environment variables file exists
3. Check if plan file exists
4. Run terraform apply with the saved plan
5. Display apply results

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
Write-ColorOutput "Applying Layer: $Layer (Environment: $Environment)" "Info"
Write-ColorOutput "=============================================================================" "Info"

# Plan 파일 경로 확인
$PlanFile = Join-Path $LayerDir "tfplan"

if (-not (Test-Path $PlanFile)) {
    Write-ColorOutput "[ERROR] Plan file not found: $PlanFile" "Error"
    Write-ColorOutput "[INFO] Please run plan-layer.ps1 first to create a plan file" "Info"
    exit 5
}

# 사용자 확인 (AutoApprove가 아닌 경우)
if (-not $AutoApprove) {
    Write-ColorOutput "" "Warning"
    Write-ColorOutput "WARNING: This will apply changes to AWS infrastructure!" "Warning"
    Write-ColorOutput "Layer: $Layer" "Warning"
    Write-ColorOutput "Environment: $Environment" "Warning"
    Write-ColorOutput "" "Warning"

    $confirmation = Read-Host "Do you want to continue? (yes/no)"
    if ($confirmation -ne "yes") {
        Write-ColorOutput "[INFO] Apply cancelled by user" "Info"
        exit 0
    }
}

# Terraform apply 실행
Write-ColorOutput "[INFO] Running terraform apply for layer $Layer" "Info"
$ApplyArgs = @(
    "-chdir=$LayerDir",
    "apply",
    "-input=false"
)

if ($AutoApprove) {
    $ApplyArgs += "-auto-approve"
}

$ApplyArgs += "tfplan"

Write-ColorOutput "[INFO] Running: terraform $($ApplyArgs -join ' ')" "Info"

try {
    & terraform @ApplyArgs
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "[SUCCESS] Apply completed successfully for layer $Layer" "Success"

        # Plan 파일 삭제 (선택적)
        try {
            Remove-Item $PlanFile -Force
            Write-ColorOutput "[INFO] Plan file cleaned up: $PlanFile" "Info"
        } catch {
            Write-ColorOutput "[WARNING] Could not clean up plan file: $($_.Exception.Message)" "Warning"
        }
    } else {
        Write-ColorOutput "[ERROR] Apply failed for layer $Layer (exit code: $LASTEXITCODE)" "Error"
        exit 1
    }
} catch {
    Write-ColorOutput "[ERROR] Exception during apply: $($_.Exception.Message)" "Error"
    exit 1
}

# 완료 메시지
Write-ColorOutput "" "Info"
Write-ColorOutput "=============================================================================" "Success"
Write-ColorOutput "Layer $Layer apply completed successfully!" "Success"
Write-ColorOutput "=============================================================================" "Success"