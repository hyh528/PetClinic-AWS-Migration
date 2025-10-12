#!/usr/bin/env pwsh
# ==========================================
# Terraform 인프라 전체 검증 스크립트 (PowerShell 버전)
# ==========================================
# 모든 레이어를 한 번에 init, validate, plan 수행

param(
    [Parameter(Mandatory = $true, HelpMessage = "Environment name (dev, staging, prod)")]
    [ValidateSet("dev", "staging", "prod")]
    [string]$Environment,

    [Parameter(HelpMessage = "Show help message")]
    [switch]$Help
)

# Color output function
function Write-ColorOutput {
    param([string]$Message, [string]$Type = "Info")
    switch ($Type) {
        "Success" { Write-Host $Message -ForegroundColor Green }
        "Error" { Write-Host $Message -ForegroundColor Red }
        "Warning" { Write-Host $Message -ForegroundColor Yellow }
        default { Write-Host $Message -ForegroundColor Cyan }
    }
}

# Help display function
function Show-Help {
    Write-Host @"
==========================================
Terraform Infrastructure Validation Script
==========================================

Usage:
    .\validate-infrastructure.ps1 -Environment <env> [-Help]

Parameters:
    -Environment    Environment name (dev, staging, prod)
    -Help           Show this help message

This script will validate all layers in the correct order:
    01-network, 02-security, 03-database, 04-parameter-store,
    05-cloud-map, 06-lambda-genai, 07-application, 08-api-gateway,
    09-monitoring

==========================================
"@ -ForegroundColor Cyan
}

# Show help if requested
if ($Help) {
    Show-Help
    exit 0
}

Write-ColorOutput "==========================================" "Info"
Write-ColorOutput "Terraform Infrastructure Validation Started" "Info"
Write-ColorOutput "Environment: $Environment" "Info"
Write-ColorOutput "==========================================" "Info"

# =============================================================================
# Configuration
# =============================================================================

# Define layers in execution order
$Layers = @(
    "01-network",
    "02-security",
    "03-database",
    "04-parameter-store",
    "05-cloud-map",
    "06-lambda-genai",
    "07-application",
    "08-api-gateway",
    "09-monitoring"
)

$LayerDescriptions = @{
    "01-network" = "기본 네트워크 인프라 (VPC, 서브넷, 게이트웨이)"
    "02-security" = "보안 설정 (보안 그룹, IAM, VPC 엔드포인트)"
    "03-database" = "데이터베이스 (Aurora 클러스터)"
    "04-parameter-store" = "Parameter Store (Spring Cloud Config 대체)"
    "05-cloud-map" = "Cloud Map (Eureka 대체)"
    "06-lambda-genai" = "Lambda GenAI (서버리스 AI 서비스)"
    "07-application" = "애플리케이션 인프라 (ECS, ALB, ECR)"
    "08-api-gateway" = "API Gateway (Spring Cloud Gateway 대체)"
    "09-monitoring" = "모니터링 (CloudWatch 통합)"
}

# Path configuration
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)
$EnvDir = Join-Path $ProjectRoot "layers"

# Initialize counters
$Errors = 0
$Warnings = 0
$SuccessLayers = @()
$FailedLayers = @()

# =============================================================================
# Step 1: Pre-validation
# =============================================================================

Write-ColorOutput "" "Info"
Write-ColorOutput "=== Step 1: Pre-validation ===" "Info"

# Check if terraform is installed
try {
    $terraformVersion = & terraform version | Select-Object -First 1
    Write-ColorOutput "[SUCCESS] Terraform found: $terraformVersion" "Success"
} catch {
    Write-ColorOutput "[ERROR] Terraform not found or not in PATH" "Error"
    exit 1
}

# Check if environment directory exists
if (-not (Test-Path $EnvDir)) {
    Write-ColorOutput "[ERROR] Environment directory does not exist: $EnvDir" "Error"
    exit 1
}

Write-ColorOutput "[SUCCESS] Environment directory found: $EnvDir" "Success"

# =============================================================================
# Step 2: Format check
# =============================================================================

Write-ColorOutput "" "Info"
Write-ColorOutput "=== Step 2: Format check ===" "Info"

Push-Location $ProjectRoot

try {
    $formatResult = & terraform fmt -check -recursive 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "[SUCCESS] Terraform formatting is correct" "Success"
    } else {
        Write-ColorOutput "[WARNING] Terraform formatting issues found - fixing..." "Warning"
        & terraform fmt -recursive | Out-Null
        Write-ColorOutput "[SUCCESS] Terraform formatting fixed" "Success"
        $Warnings++
    }
} catch {
    Write-ColorOutput "[WARNING] Terraform format check failed: $($_.Exception.Message)" "Warning"
    $Warnings++
}

Pop-Location

# =============================================================================
# Step 3: Layer validation
# =============================================================================

Write-ColorOutput "" "Info"
Write-ColorOutput "=== Step 3: Layer validation ===" "Info"

foreach ($Layer in $Layers) {
    $layerDir = Join-Path $EnvDir $Layer

    if (-not (Test-Path $layerDir)) {
        Write-ColorOutput "[WARNING] Layer directory does not exist: $layerDir (skipping)" "Warning"
        $Warnings++
        continue
    }

    Write-ColorOutput "" "Info"
    Write-ColorOutput "==========================================" "Info"
    Write-ColorOutput "Validating Layer: $Layer" "Info"
    Write-ColorOutput "Description: $($LayerDescriptions[$Layer])" "Info"
    Write-ColorOutput "==========================================" "Info"

    Push-Location $layerDir

    try {
        # Check required files
        $requiredFiles = @("main.tf", "variables.tf", "outputs.tf")
        foreach ($file in $requiredFiles) {
            if (Test-Path $file) {
                Write-ColorOutput "  ✅ $file exists" "Success"
            } else {
                Write-ColorOutput "  ⚠️  $file missing" "Warning"
                $Warnings++
            }
        }

        # Terraform init
        Write-ColorOutput "  🔧 Initializing Terraform..." "Info"
        $initResult = & terraform init -input=false -upgrade 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "  ✅ Initialization successful" "Success"
        } else {
            Write-ColorOutput "  ❌ Initialization failed" "Error"
            $initResult | ForEach-Object { Write-ColorOutput "    $_" "Error" }
            $FailedLayers += $Layer
            $Errors++
            Pop-Location
            continue
        }

        # Terraform validate
        Write-ColorOutput "  🔍 Validating Terraform..." "Info"
        $validateResult = & terraform validate 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "  ✅ Validation passed" "Success"
        } else {
            Write-ColorOutput "  ❌ Validation failed" "Error"
            $validateResult | ForEach-Object { Write-ColorOutput "    $_" "Error" }
            $FailedLayers += $Layer
            $Errors++
            Pop-Location
            continue
        }

        # Terraform plan (if tfvars file exists)
        $tfvarsFile = "$Environment.tfvars"
        if (Test-Path $tfvarsFile) {
            Write-ColorOutput "  📋 Generating Terraform plan..." "Info"
            $planResult = & terraform plan -var-file="$tfvarsFile" -input=false 2>&1
            if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq 2) {
                Write-ColorOutput "  ✅ Plan generation successful" "Success"
            } else {
                Write-ColorOutput "  ❌ Plan generation failed" "Error"
                $planResult | ForEach-Object { Write-ColorOutput "    $_" "Error" }
                $FailedLayers += $Layer
                $Errors++
                Pop-Location
                continue
            }
        } else {
            Write-ColorOutput "  ⚠️  tfvars file not found: $tfvarsFile" "Warning"
            $Warnings++
        }

        $SuccessLayers += $Layer
        Write-ColorOutput "Layer validation completed: $Layer" "Success"

    } catch {
        Write-ColorOutput "[ERROR] Exception during $Layer validation: $($_.Exception.Message)" "Error"
        $FailedLayers += $Layer
        $Errors++
    } finally {
        Pop-Location
    }
}

# =============================================================================
# Step 4: Security scan (optional)
# =============================================================================

Write-ColorOutput "" "Info"
Write-ColorOutput "=== Step 4: Security scan ===" "Info"

Push-Location $ProjectRoot

# Checkov scan
try {
    $checkovVersion = & checkov --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "Running Checkov security scan..." "Info"
        $checkovResult = & checkov -d . --framework terraform --quiet 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "[SUCCESS] Checkov security scan passed" "Success"
        } else {
            Write-ColorOutput "[WARNING] Checkov security scan found issues" "Warning"
            $Warnings++
        }
    }
} catch {
    Write-ColorOutput "[WARNING] Checkov not installed, skipping security scan" "Warning"
}

# tfsec scan
try {
    $tfsecVersion = & tfsec --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-ColorOutput "Running tfsec security scan..." "Info"
        $tfsecResult = & tfsec . 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "[SUCCESS] tfsec security scan passed" "Success"
        } else {
            Write-ColorOutput "[WARNING] tfsec security scan found issues" "Warning"
            $Warnings++
        }
    }
} catch {
    Write-ColorOutput "[WARNING] tfsec not installed, skipping security scan" "Warning"
}

Pop-Location

# =============================================================================
# Step 5: Results summary
# =============================================================================

Write-ColorOutput "" "Info"
Write-ColorOutput "=== Validation Results Summary ===" "Info"

Write-ColorOutput "==========================================" "Info"
Write-ColorOutput "📊 Validation Statistics:" "Info"
Write-ColorOutput "   - Total Layers: $($Layers.Count)" "Info"
Write-ColorOutput "   - Successful: $($SuccessLayers.Count)" "Success"
Write-ColorOutput "   - Failed: $($FailedLayers.Count)" "Error"
Write-ColorOutput "   - Errors: $Errors" "Error"
Write-ColorOutput "   - Warnings: $Warnings" "Warning"
Write-ColorOutput "==========================================" "Info"

if ($SuccessLayers.Count -gt 0) {
    Write-ColorOutput "" "Success"
    Write-ColorOutput "Successful Layers:" "Success"
    foreach ($layer in $SuccessLayers) {
        Write-ColorOutput "  ✓ $layer - $($LayerDescriptions[$layer])" "Success"
    }
}

if ($FailedLayers.Count -gt 0) {
    Write-ColorOutput "" "Error"
    Write-ColorOutput "Failed Layers:" "Error"
    foreach ($layer in $FailedLayers) {
        Write-ColorOutput "  ✗ $layer - $($LayerDescriptions[$layer])" "Error"
    }
}

Write-ColorOutput "" "Info"

if ($Errors -eq 0 -and $Warnings -eq 0) {
    Write-ColorOutput "🎉 All validations passed!" "Success"
    Write-ColorOutput "" "Info"
    Write-ColorOutput "Next steps:" "Info"
    Write-ColorOutput "1. .\plan-all.ps1 $Environment    # Review deployment plan" "Info"
    Write-ColorOutput "2. .\apply-all.ps1 $Environment   # Execute deployment" "Info"

} elseif ($Errors -eq 0) {
    Write-ColorOutput "⚠️  Warnings found but deployment possible." "Warning"
    Write-ColorOutput "" "Info"
    Write-ColorOutput "Recommendations:" "Info"
    Write-ColorOutput "1. Review and fix warnings" "Info"
    Write-ColorOutput "2. .\plan-all.ps1 $Environment" "Info"

} else {
    Write-ColorOutput "❌ Errors found. Fix required before deployment." "Error"
    Write-ColorOutput "" "Info"
    Write-ColorOutput "Solutions:" "Info"
    Write-ColorOutput "1. Check error messages above" "Info"
    Write-ColorOutput "2. Fix terraform files in failed layers" "Info"
    Write-ColorOutput "3. Run validation again" "Info"

    exit 1
}

Write-ColorOutput "Validation script completed!" "Success"