#!/usr/bin/env pwsh
# =============================================================================
# Terraform All Layers Initialization Script
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
Terraform All Layers Initialization Script
=============================================================================

Usage:
    .\init-all.ps1 -Environment <env> [-Help]

Parameters:
    -Environment    Environment name (dev, staging, prod)
    -Help           Show this help message

Examples:
    .\init-all.ps1 -Environment dev
    .\init-all.ps1 -Environment prod

This script will initialize all layers in the correct order:
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
Write-ColorOutput "Terraform All Layers Initialization Started" "Info"
Write-ColorOutput "Environment: $Environment" "Info"
Write-ColorOutput "==============================================================================" "Info"

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
    "09-monitoring",
    "10-aws-native"
)

# Path configuration
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)
$LayersDir = Join-Path $ProjectRoot "layers"

# =============================================================================
# Step 1: Clean up any previously copied shared files
# =============================================================================

Write-ColorOutput "" "Info"
Write-ColorOutput "Step 1: Cleaning up previously copied shared files..." "Info"
Write-ColorOutput "==============================================================================" "Info"

# Define shared files to copy to layers
$SharedFiles = @(
    "provider.tf",
    "versions.tf"
)

foreach ($Layer in $Layers) {
    $LayerDir = Join-Path $LayersDir $Layer
    
    if (-not (Test-Path $LayerDir)) {
        Write-ColorOutput "[WARNING] Layer directory does not exist: $LayerDir" "Warning"
        continue
    }
    
    foreach ($SharedFile in $SharedFiles) {
        $DestFile = Join-Path $LayerDir $SharedFile
        
        if (Test-Path $DestFile) {
            try {
                Remove-Item $DestFile -Force
                Write-ColorOutput "[SUCCESS] Removed duplicate $SharedFile from $Layer" "Success"
            } catch {
                Write-ColorOutput "[WARNING] Failed to remove $SharedFile from $Layer`: $($_.Exception.Message)" "Warning"
            }
        }
    }
}

Write-ColorOutput "[SUCCESS] Cleanup completed! Using terraform -chdir approach." "Success"

# =============================================================================
# Step 1.5: Copy shared files to layers
# =============================================================================

Write-ColorOutput "" "Info"
Write-ColorOutput "Step 1.5: Copying shared files to layers..." "Info"
Write-ColorOutput "==============================================================================" "Info"

foreach ($Layer in $Layers) {
    $LayerDir = Join-Path $LayersDir $Layer

    if (-not (Test-Path $LayerDir)) {
        Write-ColorOutput "[WARNING] Layer directory does not exist: $LayerDir" "Warning"
        continue
    }

    foreach ($SharedFile in $SharedFiles) {
        $SrcFile = Join-Path $ProjectRoot $SharedFile
        $DestFile = Join-Path $LayerDir $SharedFile

        if (Test-Path $SrcFile) {
            try {
                Copy-Item $SrcFile $DestFile -Force
                Write-ColorOutput "[SUCCESS] Copied $SharedFile to $Layer" "Success"
            } catch {
                Write-ColorOutput "[WARNING] Failed to copy $SharedFile to $Layer`: $($_.Exception.Message)" "Warning"
            }
        } else {
            Write-ColorOutput "[WARNING] Shared file does not exist: $SrcFile" "Warning"
        }
    }
}

Write-ColorOutput "[SUCCESS] Shared files copy completed!" "Success"

# =============================================================================
# Step 2: Initialize each layer using terraform -chdir
# =============================================================================

Write-ColorOutput "" "Info"
Write-ColorOutput "Step 2: Initializing all layers using terraform -chdir..." "Info"
Write-ColorOutput "==============================================================================" "Info"

$BackendConfig = "backend.hcl"
$EnvVarsFile = "envs/$Environment.tfvars"

# Check if required files exist
if (-not (Test-Path $BackendConfig)) {
    Write-ColorOutput "[ERROR] Backend config file does not exist: $BackendConfig" "Error"
    exit 1
}

if (-not (Test-Path $EnvVarsFile)) {
    Write-ColorOutput "[ERROR] Environment variables file does not exist: $EnvVarsFile" "Error"
    exit 1
}

# Initialize counters
$SuccessCount = 0
$FailureCount = 0
$FailedLayers = @()

# Initialize each layer
foreach ($Layer in $Layers) {
    Write-ColorOutput "" "Info"
    Write-ColorOutput "==============================================================================" "Info"
    Write-ColorOutput "Initializing Layer: $Layer" "Info"
    Write-ColorOutput "==============================================================================" "Info"
    
    $LayerDir = "layers\$Layer"
    
    if (-not (Test-Path $LayerDir)) {
        Write-ColorOutput "[WARNING] Layer directory does not exist: $LayerDir (skipping)" "Warning"
        continue
    }
    
    try {
        # Initialize with S3 backend using terraform -chdir
        $StateKey = "$Environment/$Layer/terraform.tfstate"
        Write-ColorOutput "[INFO] State key: $StateKey" "Info"
        
        $InitArgs = @(
            "-chdir=$LayerDir",
            "init",
            "-input=false",
            "-upgrade",
            "-reconfigure",
            "-backend-config=..\..\$BackendConfig",
            "-backend-config=key=$StateKey"
        )
        
        Write-ColorOutput "[INFO] Running: terraform $($InitArgs -join ' ')" "Info"
        
        & terraform @InitArgs
        
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "[SUCCESS] Layer $Layer initialized successfully!" "Success"
            $SuccessCount++
        } else {
            Write-ColorOutput "[ERROR] Layer $Layer initialization failed!" "Error"
            $FailureCount++
            $FailedLayers += $Layer
        }
    } catch {
        Write-ColorOutput "[ERROR] Exception during $Layer initialization: $($_.Exception.Message)" "Error"
        $FailureCount++
        $FailedLayers += $Layer
    }
}

# Summary
Write-ColorOutput "" "Info"
Write-ColorOutput "==============================================================================" "Info"
Write-ColorOutput "INITIALIZATION SUMMARY" "Info"
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
    Write-ColorOutput "🎉 All layers initialized successfully!" "Success"
    Write-ColorOutput "Next step: Run terraform plan or apply for each layer" "Info"
    exit 0
}