#!/usr/bin/env pwsh
# =============================================================================
# Terraform Layer Initialization Script (PowerShell)
# =============================================================================
# 목적: 단일 레이어를 초기화하고 검증
# 사용법: .\init-layer.ps1 -Layer <layer-name> [-Environment <env>]
# 예시: .\init-layer.ps1 -Layer 02-security -Environment dev

param(
    [Parameter(Mandatory = $true, HelpMessage = "Layer name (e.g., 02-security)")]
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
Terraform Layer Initialization Script (PowerShell)
=============================================================================

Usage:
    .\init-layer.ps1 -Layer <layer-name> [-Environment <env>] [-Help]

Parameters:
    -Layer          Layer name (e.g., 02-security, 03-database)
    -Environment    Environment name (default: dev)
    -Help           Show this help message

Examples:
    .\init-layer.ps1 -Layer 02-security
    .\init-layer.ps1 -Layer 03-database -Environment staging
    .\init-layer.ps1 -Help

This script will:
1. Format Terraform files (terraform fmt)
2. Initialize the layer with backend configuration
3. Validate the Terraform configuration

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

Write-ColorOutput "=============================================================================" "Info"
Write-ColorOutput "Initializing Layer: $Layer (Environment: $Environment)" "Info"
Write-ColorOutput "=============================================================================" "Info"

# 1. Terraform 파일 포맷팅
Write-ColorOutput "[INFO] Formatting Terraform files in $LayerDir" "Info"
try {
    & terraform -chdir="$LayerDir" fmt -recursive
    Write-ColorOutput "[SUCCESS] Terraform files formatted" "Success"
} catch {
    Write-ColorOutput "[WARNING] Terraform fmt failed, but continuing..." "Warning"
}

# 2. 백엔드 설정 구성
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

# 3. Terraform 초기화
Write-ColorOutput "[INFO] Initializing Terraform backend for layer $Layer" "Info"
$InitArgs = @(
    "-chdir=$LayerDir",
    "init"
) + $BackendArgs + @(
    "-reconfigure",
    "-upgrade",
    "-input=false"
)

Write-ColorOutput "[INFO] Running: terraform $($InitArgs -join ' ')" "Info"

try {
    & terraform @InitArgs
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "[SUCCESS] Layer $Layer initialized successfully" "Success"
    } else {
        Write-ColorOutput "[ERROR] Layer $Layer initialization failed" "Error"
        exit 1
    }
} catch {
    Write-ColorOutput "[ERROR] Exception during initialization: $($_.Exception.Message)" "Error"
    exit 1
}

# 4. Terraform 검증
Write-ColorOutput "[INFO] Validating Terraform configuration in $LayerDir" "Info"
try {
    & terraform -chdir="$LayerDir" validate
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "[SUCCESS] Layer $Layer validation passed" "Success"
    } else {
        Write-ColorOutput "[ERROR] Layer $Layer validation failed" "Error"
        exit 1
    }
} catch {
    Write-ColorOutput "[ERROR] Exception during validation: $($_.Exception.Message)" "Error"
    exit 1
}

# 5. 완료 메시지
Write-ColorOutput "" "Info"
Write-ColorOutput "=============================================================================" "Success"
Write-ColorOutput "Layer $Layer initialization and validation completed successfully!" "Success"
Write-ColorOutput "Next steps:" "Info"
Write-ColorOutput "  1. Review changes: terraform -chdir='$LayerDir' plan" "Info"
Write-ColorOutput "  2. Apply changes:  terraform -chdir='$LayerDir' apply" "Info"
Write-ColorOutput "=============================================================================" "Success"