# Terraform Static Analysis Script (PowerShell)
# This script runs terraform fmt, validate, tflint, checkov sequentially

param(
    [string]$TerraformDir = (Get-Location).Path,
    [switch]$SkipInit = $false,
    [switch]$Verbose = $false
)

$ErrorActionPreference = "Stop"

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

function Test-Tool {
    param(
        [string]$ToolName,
        [string]$InstallCommand
    )
    
    try {
        $null = Get-Command $ToolName -ErrorAction Stop
        return $true
    }
    catch {
        Log-Warning "$ToolName is not installed."
        Log-Info "Install command: $InstallCommand"
        return $false
    }
}

# Main execution starts
Log-Info "Starting Terraform static analysis in: $TerraformDir"

# Change to working directory
Set-Location $TerraformDir

# Check available tools
Log-Info "Checking available tools..."

$hasTerraform = Test-Tool "terraform" "https://www.terraform.io/downloads.html"
$hasTflint = Test-Tool "tflint" "choco install tflint or https://github.com/terraform-linters/tflint/releases"
$hasCheckov = Test-Tool "checkov" "pip install checkov"

if (-not $hasTerraform) {
    Log-Error "Terraform is required but not installed. Please install it and run again."
    exit 1
}

if (-not $hasTflint) {
    Log-Warning "TFLint is not available. Skipping TFLint checks."
}

if (-not $hasCheckov) {
    Log-Warning "Checkov is not available. Skipping security checks."
}

# Result tracking variables
$script:Errors = 0
$script:Warnings = 0

# 1. Terraform Format Check
Log-Info "1. Running Terraform Format check..."
try {
    $formatResult = terraform fmt -check -recursive -diff
    if ($LASTEXITCODE -eq 0) {
        Log-Success "Terraform Format check passed"
    } else {
        Log-Error "Terraform Format check failed"
        Log-Info "Run 'terraform fmt -recursive' to auto-fix formatting issues"
        $script:Errors++
    }
} catch {
    Log-Error "Error during Terraform Format check: $($_.Exception.Message)"
    $script:Errors++
}

Write-Host ""

# 2. Terraform Validate Check
Log-Info "2. Running Terraform Validate check..."

$validateErrors = 0
$layerDirs = Get-ChildItem -Path "layers" -Directory -ErrorAction SilentlyContinue

if ($layerDirs) {
    foreach ($layerDir in $layerDirs) {
        $layerName = $layerDir.Name
        Log-Info "  Validating layer: $layerName"
        
        Push-Location $layerDir.FullName
        
        try {
            # Check if terraform init is needed
            if (-not (Test-Path ".terraform")) {
                if (-not $SkipInit) {
                    Log-Info "    Initializing Terraform..."
                    terraform init -backend=false | Out-Null
                    if ($LASTEXITCODE -ne 0) {
                        Log-Error "    $layerName initialization failed"
                        $validateErrors++
                        Pop-Location
                        continue
                    }
                }
            }
            
            # Run validate
            terraform validate | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Log-Success "    $layerName validation passed"
            } else {
                Log-Error "    $layerName validation failed"
                terraform validate
                $validateErrors++
            }
        } catch {
            Log-Error "    Error validating $layerName : $($_.Exception.Message)"
            $validateErrors++
        } finally {
            Pop-Location
        }
    }
} else {
    # If no layers folder, validate current directory
    try {
        if (-not (Test-Path ".terraform") -and -not $SkipInit) {
            Log-Info "Initializing Terraform..."
            terraform init -backend=false | Out-Null
        }
        
        terraform validate | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Log-Success "Terraform Validate check passed"
        } else {
            Log-Error "Terraform Validate check failed"
            terraform validate
            $validateErrors++
        }
    } catch {
        Log-Error "Error during Terraform Validate check: $($_.Exception.Message)"
        $validateErrors++
    }
}

if ($validateErrors -eq 0) {
    Log-Success "Terraform Validate check passed"
} else {
    Log-Error "Terraform Validate check failed ($validateErrors layers)"
    $script:Errors++
}

Write-Host ""

# 3. TFLint Check
Log-Info "3. Running TFLint check..."

try {
    # Check if .tflint.hcl config file exists
    if (-not (Test-Path ".tflint.hcl")) {
        Log-Warning ".tflint.hcl config file not found. Running with default settings."
    }

    # Initialize TFLint
    tflint --init | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Log-Info "TFLint initialization completed"
    } else {
        Log-Warning "TFLint initialization failed, continuing with default settings"
    }

    # Run TFLint
    tflint --recursive --format=compact
    if ($LASTEXITCODE -eq 0) {
        Log-Success "TFLint check passed"
    } else {
        Log-Warning "TFLint found warnings or errors"
        $script:Warnings++
    }
} catch {
    Log-Error "Error during TFLint check: $($_.Exception.Message)"
    $script:Warnings++
}

Write-Host ""

# 4. Checkov Security Check
Log-Info "4. Running Checkov security check..."

try {
    # Run Checkov
    $checkovArgs = @(
        "-d", ".",
        "--framework", "terraform",
        "--output", "cli",
        "--output", "json",
        "--output-file-path", "console,checkov-report.json"
    )
    
    & checkov @checkovArgs
    $checkovExitCode = $LASTEXITCODE
    
    Log-Success "Checkov security check completed"
    
    # Output result summary
    if (Test-Path "checkov-report.json") {
        Log-Info "Security check results saved to checkov-report.json"
        
        # Try to extract statistics from JSON
        try {
            $checkovReport = Get-Content "checkov-report.json" | ConvertFrom-Json
            if ($checkovReport.summary) {
                $passed = $checkovReport.summary.passed
                $failed = $checkovReport.summary.failed
                $skipped = $checkovReport.summary.skipped
                
                Log-Info "  Passed: $passed, Failed: $failed, Skipped: $skipped"
                
                if ($failed -gt 0) {
                    Log-Warning "Security check found $failed issues"
                    $script:Warnings++
                }
            }
        } catch {
            Log-Warning "Error parsing Checkov results: $($_.Exception.Message)"
        }
    }
    
    if ($checkovExitCode -ne 0) {
        Log-Warning "Checkov found some issues"
        $script:Warnings++
    }
} catch {
    Log-Error "Error during Checkov security check: $($_.Exception.Message)"
    $script:Errors++
}

Write-Host ""

# 5. Result Summary
Log-Info "=== Static Analysis Result Summary ==="
Write-Host ""

if ($script:Errors -eq 0 -and $script:Warnings -eq 0) {
    Log-Success "All static analysis checks completed successfully! ✅"
    exit 0
} elseif ($script:Errors -eq 0) {
    Log-Warning "Static analysis completed with $($script:Warnings) warnings ⚠️"
    exit 0
} else {
    Log-Error "Static analysis found $($script:Errors) errors and $($script:Warnings) warnings ❌"
    Write-Host ""
    Log-Info "Recommended next steps:"
    Log-Info "1. terraform fmt -recursive (fix formatting)"
    Log-Info "2. Fix terraform validate errors"
    Log-Info "3. Review TFLint recommendations"
    Log-Info "4. Resolve Checkov security issues"
    exit 1
}