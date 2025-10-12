#!/usr/bin/env pwsh
# =============================================================================
# Terraform Apply All Layers Script
# =============================================================================

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
==============================================================================
Terraform Apply All Layers Script
==============================================================================

Usage:
    .\apply-all.ps1 -Environment <env> [-Help]

Parameters:
    -Environment    Environment name (dev, staging, prod)
    -Help           Show this help message

Examples:
    .\apply-all.ps1 -Environment dev
    .\apply-all.ps1 -Environment prod

This script will run terraform apply for all layers in the correct order:
    01-network, 02-security, 03-database, 04-parameter-store,
    05-cloud-map, 06-lambda-genai, 07-application, 08-api-gateway,
    09-monitoring, 10-aws-native

==============================================================================
"@ -ForegroundColor Cyan
}

# Show help if requested
if ($Help) {
    Show-Help
    exit 0
}

Write-ColorOutput "==============================================================================" "Info"
Write-ColorOutput "Terraform Apply All Layers Started" "Info"
Write-ColorOutput "Environment: $Environment" "Info"
Write-ColorOutput "==============================================================================" "Info"

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
    "09-monitoring",
    "10-aws-native"
)

# Path configuration
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)
$LayersDir = Join-Path $ProjectRoot "layers"
$EnvVarsFile = Join-Path $ProjectRoot "envs/$Environment.tfvars"

# Check if environment variables file exists
if (-not (Test-Path $EnvVarsFile)) {
    Write-ColorOutput "[ERROR] Environment variables file does not exist: $EnvVarsFile" "Error"
    exit 1
}

# Initialize counters
$SuccessCount = 0
$FailureCount = 0
$FailedLayers = @()

# Apply each layer
foreach ($Layer in $Layers) {
    Write-ColorOutput "" "Info"
    Write-ColorOutput "==============================================================================" "Info"
    Write-ColorOutput "Applying Layer: $Layer" "Info"
    Write-ColorOutput "==============================================================================" "Info"

    $LayerDir = Join-Path $LayersDir $Layer

    if (-not (Test-Path $LayerDir)) {
        Write-ColorOutput "[ERROR] Layer directory does not exist: $LayerDir" "Error"
        $FailureCount++
        $FailedLayers += $Layer
        continue
    }

    try {
        Write-ColorOutput "[INFO] Running terraform apply for layer: $Layer" "Info"

        # Ensure the layer is initialized
        $InitArgs = @(
            "-chdir=$LayerDir"
            "init"
            "-upgrade"
            "-input=false"
            "-reconfigure"
        )

        Write-ColorOutput "[INFO] Initializing layer: $Layer" "Info"
        & terraform @InitArgs

        if ($LASTEXITCODE -ne 0) {
            Write-ColorOutput "[ERROR] Failed to initialize layer: $Layer" "Error"
            $FailureCount++
            $FailedLayers += $Layer
            continue
        }

        # Run terraform apply using -chdir
        $VarFile = Join-Path $ProjectRoot "envs/$Environment.tfvars"
        $ApplyArgs = @(
            "-chdir=$LayerDir"
            "apply"
            "-var-file=$VarFile"
            "-input=false"
            "-auto-approve"
        )

        Write-ColorOutput "[INFO] Running terraform apply..." "Info"
        & terraform @ApplyArgs

        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "[SUCCESS] Layer $Layer applied successfully!" "Success"
            $SuccessCount++
        } else {
            Write-ColorOutput "[ERROR] Layer $Layer apply failed!" "Error"
            $FailureCount++
            $FailedLayers += $Layer
        }

    } catch {
        Write-ColorOutput "[ERROR] Exception during $Layer applying: $($_.Exception.Message)" "Error"
        $FailureCount++
        $FailedLayers += $Layer
    }
}

# Summary
Write-ColorOutput "" "Info"
Write-ColorOutput "==============================================================================" "Info"
Write-ColorOutput "APPLY SUMMARY" "Info"
Write-ColorOutput "==============================================================================" "Info"
Write-ColorOutput "Total Layers: $($Layers.Count)" "Info"
Write-ColorOutput "Successful: $SuccessCount" "Success"
Write-ColorOutput "Failed: $FailureCount" "Error"

if ($FailureCount -gt 0) {
    Write-ColorOutput "" "Error"
    Write-ColorOutput "Failed Layers:" "Error"
    foreach ($FailedLayer in $FailedLayers) {
        Write-ColorOutput "  - $FailedLayer" "Error"
    }
    Write-ColorOutput "" "Error"
    Write-ColorOutput "Please check the errors above and retry failed layers individually." "Warning"
    exit 1
} else {
    Write-ColorOutput "" "Success"
    Write-ColorOutput "🎉 All layers applied successfully!" "Success"
    Write-ColorOutput "Next step: Run validate-infrastructure.ps1 to verify the deployment" "Info"
    exit 0
}