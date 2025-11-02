# Terraform Static Analysis Runner (PowerShell)
# This script helps run static analysis tools easily

param(
    [string]$TerraformDir = "",
    [switch]$FormatOnly = $false,
    [switch]$ValidateOnly = $false,
    [switch]$LintOnly = $false,
    [switch]$SecurityOnly = $false,
    [switch]$AutoFix = $false,
    [switch]$SkipInit = $false,
    [switch]$Help = $false
)

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    
    $colorMap = @{
        "Red" = "Red"
        "Green" = "Green" 
        "Yellow" = "Yellow"
        "Blue" = "Blue"
        "White" = "White"
        "Cyan" = "Cyan"
    }
    
    Write-Host $Message -ForegroundColor $colorMap[$Color]
}

function Log-Info {
    param([string]$Message)
    Write-ColorOutput "[INFO] $Message" "Blue"
}

function Log-Success {
    param([string]$Message)
    Write-ColorOutput "[SUCCESS] $Message" "Green"
}

function Log-Warning {
    param([string]$Message)
    Write-ColorOutput "[WARNING] $Message" "Yellow"
}

function Log-Error {
    param([string]$Message)
    Write-ColorOutput "[ERROR] $Message" "Red"
}

function Show-Usage {
    Write-Host "Usage: .\run-static-analysis.ps1 [Options]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -Help               Show this help"
    Write-Host "  -TerraformDir DIR   Specify Terraform directory"
    Write-Host "  -FormatOnly         Run formatting only"
    Write-Host "  -ValidateOnly       Run validation only"
    Write-Host "  -LintOnly           Run TFLint only"
    Write-Host "  -SecurityOnly       Run Checkov security scan only"
    Write-Host "  -AutoFix            Auto-fix issues where possible"
    Write-Host "  -SkipInit           Skip Terraform init"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\run-static-analysis.ps1                    # Run all checks"
    Write-Host "  .\run-static-analysis.ps1 -FormatOnly        # Format only"
    Write-Host "  .\run-static-analysis.ps1 -AutoFix           # Auto-fix issues"
}

if ($Help) {
    Show-Usage
    exit 0
}

if ([string]::IsNullOrEmpty($TerraformDir)) {
    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $TerraformDir = Split-Path -Parent $ScriptDir
}

try {
    Set-Location $TerraformDir
    Log-Info "Starting Terraform static analysis in: $(Get-Location)"
    Write-Host ""
} catch {
    Log-Error "Cannot find directory: $TerraformDir"
    exit 1
}

$ErrorActionPreference = "Stop"

try {
    if ($FormatOnly) {
        Log-Info "Running format check only..."
        if ($AutoFix) {
            terraform fmt -recursive
            Log-Success "Terraform formatting completed"
        } else {
            terraform fmt -check -recursive -diff
            if ($LASTEXITCODE -eq 0) {
                Log-Success "Terraform format check passed"
            } else {
                Log-Warning "Some files need formatting"
            }
        }
    }
    elseif ($ValidateOnly) {
        Log-Info "Running validation only..."
        $staticAnalysisScript = Join-Path $TerraformDir "scripts\static-analysis.ps1"
        
        if (Test-Path $staticAnalysisScript) {
            if ($SkipInit) {
                & $staticAnalysisScript -TerraformDir $TerraformDir -SkipInit
            } else {
                & $staticAnalysisScript -TerraformDir $TerraformDir
            }
        } else {
            Log-Error "Cannot find static analysis script: $staticAnalysisScript"
            exit 1
        }
    }
    elseif ($LintOnly) {
        Log-Info "Running TFLint only..."
        tflint --init
        tflint --recursive --format=compact
        if ($LASTEXITCODE -eq 0) {
            Log-Success "TFLint check passed"
        } else {
            Log-Warning "TFLint found issues"
        }
    }
    elseif ($SecurityOnly) {
        Log-Info "Running security scan only..."
        $checkovArgs = @(
            "-d", ".",
            "--framework", "terraform",
            "--output", "cli",
            "--output", "json",
            "--output-file-path", "console,checkov-report.json"
        )
        
        & checkov @checkovArgs
        Log-Success "Checkov security scan completed"
    }
    else {
        # Run full static analysis
        $staticAnalysisScript = Join-Path $TerraformDir "scripts\static-analysis.ps1"
        
        if (Test-Path $staticAnalysisScript) {
            if ($SkipInit) {
                & $staticAnalysisScript -TerraformDir $TerraformDir -SkipInit
            } else {
                & $staticAnalysisScript -TerraformDir $TerraformDir
            }
        } else {
            Log-Error "Cannot find static analysis script: $staticAnalysisScript"
            exit 1
        }
    }

    Write-Host ""
    Log-Success "Static analysis execution completed!"

} catch {
    Log-Error "Error during static analysis execution: $($_.Exception.Message)"
    exit 1
}