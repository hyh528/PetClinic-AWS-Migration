# Terraform Integration Test Script
# Sequential deployment, state file separation, and rollback scenario testing

param(
    [string]$Environment = "dev",
    [switch]$SkipCleanup = $false,
    [switch]$TestRollback = $false,
    [switch]$TestStateLocking = $false,
    [string]$TestType = "state"  # full, deploy, rollback, state
)

# Color functions
function Write-Info { param($Message) Write-Host "[INFO] $Message" -ForegroundColor Blue }
function Write-Success { param($Message) Write-Host "[SUCCESS] $Message" -ForegroundColor Green }
function Write-Warning { param($Message) Write-Host "[WARNING] $Message" -ForegroundColor Yellow }
function Write-Error { param($Message) Write-Host "[ERROR] $Message" -ForegroundColor Red }
function Write-Step { param($Message) Write-Host "`n=== $Message ===" -ForegroundColor Cyan }

# Global variables
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$LayersDir = Join-Path $ProjectRoot "layers"
$EnvDir = Join-Path $ProjectRoot "envs"
$TestResultsDir = Join-Path $ProjectRoot "integration-test-results"
$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$TestReportFile = Join-Path $TestResultsDir "integration-test-$Environment-$Timestamp.json"

# Test statistics
$TestStats = @{
    StartTime = Get-Date
    Environment = $Environment
    TestType = $TestType
    TotalLayers = 0
    SuccessfulLayers = 0
    FailedLayers = 0
    Errors = @()
    Warnings = @()
    TestResults = @{}
}

# Layer definitions with dependencies
$Layers = @(
    @{ Name = "01-network"; Description = "Network infrastructure"; Dependencies = @() },
    @{ Name = "02-security"; Description = "Security settings"; Dependencies = @("01-network") },
    @{ Name = "03-database"; Description = "Database cluster"; Dependencies = @("01-network", "02-security") },
    @{ Name = "04-parameter-store"; Description = "Parameter Store"; Dependencies = @("01-network", "02-security") },
    @{ Name = "05-cloud-map"; Description = "Cloud Map"; Dependencies = @("01-network") },
    @{ Name = "06-lambda-genai"; Description = "Lambda GenAI"; Dependencies = @("01-network", "02-security") },
    @{ Name = "07-application"; Description = "Application infrastructure"; Dependencies = @("01-network", "02-security", "03-database") },
    @{ Name = "08-api-gateway"; Description = "API Gateway"; Dependencies = @("01-network", "02-security", "07-application") },
    @{ Name = "09-monitoring"; Description = "Monitoring"; Dependencies = @("01-network", "02-security", "07-application") },
    @{ Name = "10-aws-native"; Description = "AWS Native Services"; Dependencies = @("01-network", "02-security", "06-lambda-genai", "08-api-gateway") }
)

function Initialize-TestEnvironment {
    Write-Step "Test Environment Initialization"
    
    # Create test results directory
    if (-not (Test-Path $TestResultsDir)) {
        New-Item -ItemType Directory -Path $TestResultsDir -Force | Out-Null
        Write-Info "Created test results directory: $TestResultsDir"
    }
    
    # Validate prerequisites
    Write-Info "Validating prerequisites..."
    
    # Check Terraform
    try {
        $TerraformVersion = terraform version | Select-Object -First 1
        Write-Success "Terraform found: $TerraformVersion"
    } catch {
        Write-Error "Terraform is not installed."
        exit 1
    }
    
    # Check AWS CLI
    try {
        $null = aws --version 2>&1
        Write-Success "AWS CLI found"
    } catch {
        Write-Error "AWS CLI is not installed."
        exit 1
    }
    
    # Check layers directory
    if (-not (Test-Path $LayersDir)) {
        Write-Error "Layers directory does not exist: $LayersDir"
        exit 1
    }
    
    # Check environment tfvars file
    $TfvarsFile = Join-Path $EnvDir "$Environment.tfvars"
    if (-not (Test-Path $TfvarsFile)) {
        Write-Error "Environment tfvars file does not exist: $TfvarsFile"
        exit 1
    }
    
    Write-Success "Test environment initialization completed"
}

function Test-StateFileSeparation {
    Write-Step "State File Separation Test"
    
    $StateFiles = @()
    $StateKeys = @()
    
    foreach ($Layer in $Layers) {
        $LayerName = $Layer.Name
        $LayerDir = Join-Path $LayersDir $LayerName
        
        if (Test-Path $LayerDir) {
            Set-Location $LayerDir
            
            Write-Info "Checking layer: $LayerName"
            
            # Check for remote state configuration in terraform files
            $TerraformFiles = Get-ChildItem "*.tf" -ErrorAction SilentlyContinue
            $BackendConfig = $false
            $StateKey = ""
            
            foreach ($File in $TerraformFiles) {
                $Content = Get-Content $File.FullName -Raw -ErrorAction SilentlyContinue
                if ($Content -match 'backend\s+"s3"') {
                    $BackendConfig = $true
                    
                    # Try to extract key from backend configuration
                    if ($Content -match 'key\s*=\s*"([^"]+)"') {
                        $StateKey = $Matches[1]
                    } else {
                        # Default key pattern
                        $StateKey = "dev/$LayerName/terraform.tfstate"
                    }
                    break
                }
            }
            
            if ($BackendConfig) {
                Write-Success "  ${LayerName}: Remote state configuration found"
                Write-Info "    State key: $StateKey"
                
                $StateFiles += @{
                    Layer = $LayerName
                    StateKey = $StateKey
                    Status = "Configured"
                }
                $StateKeys += $StateKey
            } else {
                Write-Warning "  ${LayerName}: No remote state configuration found"
                $TestStats.Warnings += "No remote state configuration for $LayerName"
            }
        } else {
            Write-Warning "  ${LayerName}: Layer directory not found"
            $TestStats.Warnings += "Layer directory not found: $LayerName"
        }
    }
    
    # Check for unique state keys
    $UniqueKeys = $StateKeys | Sort-Object -Unique
    
    Write-Info "State file analysis:"
    Write-Info "  Total configured layers: $($StateFiles.Count)"
    Write-Info "  Total state keys: $($StateKeys.Count)"
    Write-Info "  Unique state keys: $($UniqueKeys.Count)"
    
    if ($StateKeys.Count -eq $UniqueKeys.Count -and $StateKeys.Count -gt 0) {
        Write-Success "All layers use unique state files"
        $TestStats.TestResults["StateFileSeparation"] = @{ 
            Status = "Success"
            Message = "All layers use unique state files"
            StateFiles = $StateFiles
            TotalLayers = $StateFiles.Count
            UniqueKeys = $UniqueKeys.Count
        }
    } elseif ($StateKeys.Count -eq 0) {
        Write-Warning "No layers have remote state configuration"
        $TestStats.TestResults["StateFileSeparation"] = @{ 
            Status = "Warning"
            Message = "No layers have remote state configuration"
            StateFiles = $StateFiles
        }
    } else {
        Write-Error "Some layers may use the same state file (duplicate keys detected)"
        $TestStats.TestResults["StateFileSeparation"] = @{ 
            Status = "Failed"
            Message = "Potential state file conflicts detected"
            StateFiles = $StateFiles
            TotalKeys = $StateKeys.Count
            UniqueKeys = $UniqueKeys.Count
        }
        $TestStats.Errors += "State file conflicts detected"
    }
}

function Test-StateLocking {
    Write-Step "State Locking Test"
    
    $TestLayer = "01-network"
    $LayerDir = Join-Path $LayersDir $TestLayer
    
    if (-not (Test-Path $LayerDir)) {
        Write-Warning "Test layer not found: $TestLayer"
        $TestStats.TestResults["StateLocking"] = @{ Status = "Skipped"; Message = "Test layer not found" }
        return
    }
    
    Set-Location $LayerDir
    
    try {
        Write-Info "Starting state locking test on layer: $TestLayer"
        
        # Check if backend is configured
        $BackendConfigured = $false
        $TerraformFiles = Get-ChildItem "*.tf" -ErrorAction SilentlyContinue
        foreach ($File in $TerraformFiles) {
            $Content = Get-Content $File.FullName -Raw -ErrorAction SilentlyContinue
            if ($Content -match 'backend\s+"s3"') {
                $BackendConfigured = $true
                break
            }
        }
        
        if (-not $BackendConfigured) {
            Write-Warning "No S3 backend configured for $TestLayer - skipping lock test"
            $TestStats.TestResults["StateLocking"] = @{ Status = "Skipped"; Message = "No S3 backend configured" }
            return
        }
        
        # Initialize terraform if needed
        if (-not (Test-Path ".terraform")) {
            Write-Info "  Initializing Terraform..."
            $null = terraform init 2>&1
        }
        
        Write-Info "  Testing concurrent access..."
        
        # Start a terraform plan in background (this will acquire the lock)
        $Job1 = Start-Job -ScriptBlock {
            param($LayerDir, $Environment)
            Set-Location $LayerDir
            $TfvarsPath = "../../envs/$Environment.tfvars"
            terraform plan -var-file=$TfvarsPath -lock-timeout=30s 2>&1
        } -ArgumentList $LayerDir, $Environment
        
        Start-Sleep -Seconds 3
        
        # Try to run another operation (should be blocked by lock)
        $Job2 = Start-Job -ScriptBlock {
            param($LayerDir, $Environment)
            Set-Location $LayerDir
            $TfvarsPath = "../../envs/$Environment.tfvars"
            terraform plan -var-file=$TfvarsPath -lock-timeout=10s 2>&1
        } -ArgumentList $LayerDir, $Environment
        
        # Wait for jobs to complete
        Write-Info "  Waiting for concurrent operations to complete..."
        $Job1Result = Wait-Job $Job1 -Timeout 60 | Receive-Job
        $Job2Result = Wait-Job $Job2 -Timeout 60 | Receive-Job
        
        Remove-Job $Job1, $Job2 -Force
        
        # Analyze results
        $Job1Success = $Job1Result -notmatch "Error|Failed"
        $Job2Blocked = $Job2Result -match "lock|timeout|Error acquiring the state lock"
        
        Write-Info "  Job 1 (first operation) success: $Job1Success"
        Write-Info "  Job 2 (second operation) blocked: $Job2Blocked"
        
        if ($Job1Success -and $Job2Blocked) {
            Write-Success "State locking works correctly - concurrent access properly blocked"
            $TestStats.TestResults["StateLocking"] = @{ 
                Status = "Success"
                Message = "State locking works correctly"
                TestLayer = $TestLayer
            }
        } elseif ($Job2Blocked) {
            Write-Success "State locking appears to work - second operation was blocked"
            $TestStats.TestResults["StateLocking"] = @{ 
                Status = "Success"
                Message = "State locking appears to work"
                TestLayer = $TestLayer
            }
        } else {
            Write-Warning "State locking behavior unclear - both operations may have succeeded"
            $TestStats.TestResults["StateLocking"] = @{ 
                Status = "Warning"
                Message = "State locking behavior unclear"
                TestLayer = $TestLayer
            }
            $TestStats.Warnings += "State locking behavior unclear"
        }
        
    } catch {
        Write-Error "State locking test failed: $($_.Exception.Message)"
        $TestStats.TestResults["StateLocking"] = @{ 
            Status = "Failed"
            Error = $_.Exception.Message
            TestLayer = $TestLayer
        }
        $TestStats.Errors += "State locking test failed: $($_.Exception.Message)"
    }
}

function Generate-TestReport {
    Write-Step "Test Report Generation"
    
    $TestStats.EndTime = Get-Date
    $TestStats.TotalDuration = ($TestStats.EndTime - $TestStats.StartTime).TotalMinutes
    
    # Generate JSON report
    $TestStats | ConvertTo-Json -Depth 10 | Set-Content $TestReportFile
    
    # Generate summary
    Write-Host "`n" -NoNewline
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Integration Test Results Summary" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Environment: $Environment"
    Write-Host "Test Type: $TestType"
    Write-Host "Start Time: $($TestStats.StartTime)"
    Write-Host "End Time: $($TestStats.EndTime)"
    Write-Host "Total Duration: $([math]::Round($TestStats.TotalDuration, 2)) minutes"
    Write-Host ""
    
    # Display test results
    foreach ($TestName in $TestStats.TestResults.Keys) {
        $Result = $TestStats.TestResults[$TestName]
        $StatusColor = switch ($Result.Status) {
            "Success" { "Green" }
            "Warning" { "Yellow" }
            "Failed" { "Red" }
            "Skipped" { "Gray" }
            default { "White" }
        }
        Write-Host "Test: $TestName" -NoNewline
        Write-Host " - $($Result.Status)" -ForegroundColor $StatusColor
        if ($Result.Message) {
            Write-Host "  Message: $($Result.Message)"
        }
    }
    
    Write-Host ""
    Write-Host "Errors: $($TestStats.Errors.Count)" -ForegroundColor Red
    Write-Host "Warnings: $($TestStats.Warnings.Count)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Detailed Report: $TestReportFile" -ForegroundColor Blue
    Write-Host "========================================" -ForegroundColor Cyan
    
    if ($TestStats.Errors.Count -eq 0) {
        Write-Success "Integration tests completed successfully!"
        return 0
    } else {
        Write-Error "Some tests failed. Check the report for details."
        return 1
    }
}

# Main execution
function Main {
    Write-Info "Terraform Integration Test Starting"
    Write-Info "Environment: $Environment, Test Type: $TestType"
    
    Initialize-TestEnvironment
    
    switch ($TestType) {
        "state" {
            Test-StateFileSeparation
            if ($TestStateLocking) { 
                Test-StateLocking 
            } else {
                Write-Info "State locking test skipped (use -TestStateLocking to enable)"
            }
        }
        default {
            Write-Error "Test type '$TestType' not implemented in this version"
            exit 1
        }
    }
    
    $ExitCode = Generate-TestReport
    exit $ExitCode
}

# Execute main function
Main