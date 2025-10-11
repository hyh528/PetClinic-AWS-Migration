#!/usr/bin/env pwsh
# =============================================================================
# Setup Shared Files for All Layers
# =============================================================================

param(
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
Setup Shared Files for All Layers
=============================================================================

This script copies shared configuration files to all layer directories:
- shared-variables.tf (common variables)
- provider.tf (AWS provider configuration)
- versions.tf (Terraform version constraints)

Usage:
    .\setup-shared-files.ps1 [-Help]

=============================================================================
"@ -ForegroundColor Cyan
}

# Show help if requested
if ($Help) {
    Show-Help
    exit 0
}

Write-ColorOutput "==============================================================================" "Info"
Write-ColorOutput "Setting up shared files for all layers" "Info"
Write-ColorOutput "==============================================================================" "Info"

# Path configuration
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$LayersDir = Join-Path $ProjectRoot "layers"

# Define shared files to copy
$SharedFiles = @(
    "shared-variables.tf",
    "provider.tf", 
    "versions.tf"
)

# Define layers
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

$SuccessCount = 0
$FailureCount = 0

# Copy shared files to each layer
foreach ($Layer in $Layers) {
    Write-ColorOutput "" "Info"
    Write-ColorOutput "Setting up layer: $Layer" "Info"
    
    $LayerDir = Join-Path $LayersDir $Layer
    
    if (-not (Test-Path $LayerDir)) {
        Write-ColorOutput "[ERROR] Layer directory does not exist: $LayerDir" "Error"
        $FailureCount++
        continue
    }
    
    $LayerSuccess = $true
    
    foreach ($SharedFile in $SharedFiles) {
        $SourceFile = Join-Path $ProjectRoot $SharedFile
        $DestFile = Join-Path $LayerDir $SharedFile
        
        if (-not (Test-Path $SourceFile)) {
            Write-ColorOutput "[WARNING] Source file not found: $SourceFile" "Warning"
            continue
        }
        
        try {
            Copy-Item $SourceFile $DestFile -Force
            Write-ColorOutput "[SUCCESS] Copied $SharedFile to $Layer" "Success"
        } catch {
            Write-ColorOutput "[ERROR] Failed to copy $SharedFile to $Layer`: $($_.Exception.Message)" "Error"
            $LayerSuccess = $false
        }
    }
    
    if ($LayerSuccess) {
        $SuccessCount++
    } else {
        $FailureCount++
    }
}

# Summary
Write-ColorOutput "" "Info"
Write-ColorOutput "==============================================================================" "Info"
Write-ColorOutput "SETUP SUMMARY" "Info"
Write-ColorOutput "==============================================================================" "Info"
Write-ColorOutput "Total Layers: $($Layers.Count)" "Info"
Write-ColorOutput "Successful: $SuccessCount" "Success"
Write-ColorOutput "Failed: $FailureCount" "Error"

if ($FailureCount -gt 0) {
    Write-ColorOutput "" "Error"
    Write-ColorOutput "Some layers failed to setup. Please check the errors above." "Warning"
    exit 1
} else {
    Write-ColorOutput "" "Success"
    Write-ColorOutput "🎉 All layers setup successfully!" "Success"
    Write-ColorOutput "Next step: Run plan-all.ps1 again" "Info"
    exit 0
}