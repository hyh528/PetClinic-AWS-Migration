#!/usr/bin/env pwsh
# =============================================================================
# Terraform Plan All Layers Script
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
=============================================================================
Terraform Plan All Layers Script
=============================================================================

Usage:
    .\plan-all.ps1 -Environment <env> [-Help]

Parameters:
    -Environment    Environment name (dev, staging, prod)
    -Help           Show this help message

Examples:
    .\plan-all.ps1 -Environment dev
    .\plan-all.ps1 -Environment prod

This script will run terraform plan for all layers in the correct order:
    01-network, 02-security, 03-database, 04-parameter-store,
    05-cloud-map, 06-lambda-genai, 07-application, 08-api-gateway,
    09-monitoring, 10-aws-native

=============================================================================
"@ -ForegroundColor Cyan
}

# Show help if requested
if ($Help) {
    Show-Help
    exit 0
}

Write-ColorOutput "==============================================================================" "Info"
Write-ColorOutput "Terraform Plan All Layers Started" "Info"
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

# Plan each layer
foreach ($Layer in $Layers) {
    Write-ColorOutput "" "Info"
    Write-ColorOutput "==============================================================================" "Info"
    Write-ColorOutput "Planning Layer: $Layer" "Info"
    Write-ColorOutput "==============================================================================" "Info"
    
    $LayerDir = Join-Path $LayersDir $Layer
    
    if (-not (Test-Path $LayerDir)) {
        Write-ColorOutput "[ERROR] Layer directory does not exist: $LayerDir" "Error"
        $FailureCount++
        $FailedLayers += $Layer
        continue
    }
    
    try {
        Write-ColorOutput "[INFO] Running terraform plan for layer: $Layer" "Info"

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

        # Run terraform plan using -chdir
        $VarFile = Join-Path $ProjectRoot "envs/$Environment.tfvars"
        $PlanArgs = @(
            "-chdir=$LayerDir"
            "plan"
            "-var-file=$VarFile"
            "-input=false"
            "-detailed-exitcode"
        )

        & terraform @PlanArgs

        $ExitCode = $LASTEXITCODE

        switch ($ExitCode) {
            0 {
                Write-ColorOutput "[SUCCESS] Layer $Layer - No changes needed" "Success"
                $SuccessCount++
            }
            1 {
                Write-ColorOutput "[ERROR] Layer $Layer - Plan failed!" "Error"
                $FailureCount++
                $FailedLayers += $Layer
            }
            2 {
                Write-ColorOutput "[SUCCESS] Layer $Layer - Changes detected and planned" "Success"
                $SuccessCount++
            }
            default {
                Write-ColorOutput "[ERROR] Layer $Layer - Unexpected exit code: $ExitCode" "Error"
                $FailureCount++
                $FailedLayers += $Layer
            }
        }

    } catch {
        Write-ColorOutput "[ERROR] Exception during $Layer planning: $($_.Exception.Message)" "Error"
        $FailureCount++
        $FailedLayers += $Layer
    }
}

# Summary
Write-ColorOutput "" "Info"
Write-ColorOutput "==============================================================================" "Info"
Write-ColorOutput "PLAN SUMMARY" "Info"
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
    Write-ColorOutput "Please check the errors above and fix issues before applying." "Warning"
    exit 1
} else {
    Write-ColorOutput "" "Success"
    Write-ColorOutput "🎉 All layers planned successfully!" "Success"
    Write-ColorOutput "Next step: Review the plans and run apply-all.ps1 if everything looks good" "Info"
    exit 0
}