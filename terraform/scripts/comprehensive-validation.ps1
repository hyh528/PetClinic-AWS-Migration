# Comprehensive Terraform Layer Validation Script
# Execute terraform plan on all layers to check for drift

param(
    [string]$Environment = "dev"
)

$ErrorActionPreference = "Continue"
$layers = @(
    "01-network",
    "02-security", 
    "03-database",
    "04-parameter-store",
    "05-cloud-map",
    "06-lambda-genai",
    "07-application",
    "08-api-gateway",
    "09-aws-native",
    "10-monitoring",
    "11-frontend"
)

$validationResults = @()
$totalLayers = $layers.Count
$currentLayer = 0

Write-Host "=== Starting Comprehensive Layer Validation ===" -ForegroundColor Green
Write-Host "Environment: $Environment" -ForegroundColor Yellow
Write-Host "Total Layers: $totalLayers" -ForegroundColor Yellow
Write-Host ""

foreach ($layer in $layers) {
    $currentLayer++
    $layerPath = "terraform/layers/$layer"
    
    Write-Host "[$currentLayer/$totalLayers] Validating Layer: $layer" -ForegroundColor Cyan
    Write-Host "Path: $layerPath" -ForegroundColor Gray
    
    if (-not (Test-Path $layerPath)) {
        Write-Host "ERROR: Layer directory does not exist: $layerPath" -ForegroundColor Red
        $validationResults += [PSCustomObject]@{
            Layer = $layer
            Status = "MISSING"
            Changes = 0
            Errors = @("Directory not found")
            Notes = "Layer directory does not exist"
        }
        continue
    }
    
    Push-Location $layerPath
    
    try {
        # Check Terraform initialization
        if (-not (Test-Path ".terraform")) {
            Write-Host "  Initializing Terraform..." -ForegroundColor Yellow
            $initResult = terraform init -backend-config=backend.config 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Host "  ERROR: Terraform initialization failed" -ForegroundColor Red
                Write-Host "  $initResult" -ForegroundColor Red
                $validationResults += [PSCustomObject]@{
                    Layer = $layer
                    Status = "INIT_FAILED"
                    Changes = 0
                    Errors = @($initResult)
                    Notes = "Terraform initialization failed"
                }
                continue
            }
        }
        
        # Execute Terraform Plan
        Write-Host "  Running Terraform Plan..." -ForegroundColor Yellow
        $planOutput = terraform plan -detailed-exitcode -var-file="../../envs/$Environment.tfvars" 2>&1
        $planExitCode = $LASTEXITCODE
        
        $errors = @()
        $changes = 0
        $status = "UNKNOWN"
        
        # Analyze Plan results
        switch ($planExitCode) {
            0 {
                $status = "CLEAN"
                Write-Host "  SUCCESS: No changes - state matches" -ForegroundColor Green
            }
            1 {
                $status = "ERROR"
                $errors += $planOutput
                Write-Host "  ERROR: Terraform error occurred" -ForegroundColor Red
            }
            2 {
                $status = "DRIFT_DETECTED"
                # Count changes
                $addLines = ($planOutput | Select-String "# .* will be created" | Measure-Object).Count
                $changeLines = ($planOutput | Select-String "# .* will be updated" | Measure-Object).Count
                $deleteLines = ($planOutput | Select-String "# .* will be destroyed" | Measure-Object).Count
                $changes = $addLines + $changeLines + $deleteLines
                
                Write-Host "  WARNING: Changes detected (Add: $addLines, Change: $changeLines, Delete: $deleteLines)" -ForegroundColor Yellow
            }
        }
        
        $validationResults += [PSCustomObject]@{
            Layer = $layer
            Status = $status
            Changes = $changes
            Errors = $errors
            Notes = if ($changes -gt 0) { "Manual review required" } else { "OK" }
        }
        
    }
    catch {
        Write-Host "  ERROR: Exception occurred: $($_.Exception.Message)" -ForegroundColor Red
        $validationResults += [PSCustomObject]@{
            Layer = $layer
            Status = "EXCEPTION"
            Changes = 0
            Errors = @($_.Exception.Message)
            Notes = "Script execution exception"
        }
    }
    finally {
        Pop-Location
    }
    
    Write-Host ""
}

# Results Summary
Write-Host "=== Validation Results Summary ===" -ForegroundColor Green

$cleanLayers = ($validationResults | Where-Object { $_.Status -eq "CLEAN" }).Count
$driftLayers = ($validationResults | Where-Object { $_.Status -eq "DRIFT_DETECTED" }).Count
$errorLayers = ($validationResults | Where-Object { $_.Status -eq "ERROR" -or $_.Status -eq "EXCEPTION" -or $_.Status -eq "INIT_FAILED" }).Count
$missingLayers = ($validationResults | Where-Object { $_.Status -eq "MISSING" }).Count

Write-Host "Total Layers: $totalLayers" -ForegroundColor White
Write-Host "Clean (No Changes): $cleanLayers" -ForegroundColor Green
Write-Host "Drift Detected: $driftLayers" -ForegroundColor Yellow
Write-Host "Errors: $errorLayers" -ForegroundColor Red
Write-Host "Missing Layers: $missingLayers" -ForegroundColor Magenta

Write-Host ""
Write-Host "=== Detailed Results by Layer ===" -ForegroundColor Green

foreach ($result in $validationResults) {
    $color = switch ($result.Status) {
        "CLEAN" { "Green" }
        "DRIFT_DETECTED" { "Yellow" }
        "ERROR" { "Red" }
        "EXCEPTION" { "Red" }
        "INIT_FAILED" { "Red" }
        "MISSING" { "Magenta" }
        default { "White" }
    }
    
    $statusIcon = switch ($result.Status) {
        "CLEAN" { "[OK]" }
        "DRIFT_DETECTED" { "[DRIFT]" }
        "ERROR" { "[ERROR]" }
        "EXCEPTION" { "[EXCEPTION]" }
        "INIT_FAILED" { "[INIT_FAIL]" }
        "MISSING" { "[MISSING]" }
        default { "[UNKNOWN]" }
    }
    
    Write-Host "$statusIcon $($result.Layer): $($result.Status)" -ForegroundColor $color
    if ($result.Changes -gt 0) {
        Write-Host "   Changes: $($result.Changes)" -ForegroundColor Gray
    }
    if ($result.Notes) {
        Write-Host "   Notes: $($result.Notes)" -ForegroundColor Gray
    }
}

# Generate JSON results file
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$resultFile = "terraform/validation-results-$timestamp.json"

$summaryReport = @{
    timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
    environment = $Environment
    summary = @{
        total_layers = $totalLayers
        clean_layers = $cleanLayers
        drift_layers = $driftLayers
        error_layers = $errorLayers
        missing_layers = $missingLayers
    }
    layer_results = $validationResults
}

$summaryReport | ConvertTo-Json -Depth 10 | Out-File -FilePath $resultFile -Encoding UTF8

Write-Host ""
Write-Host "=== Validation Complete ===" -ForegroundColor Green
Write-Host "Detailed results saved to: $resultFile" -ForegroundColor Cyan

# Recommendations
Write-Host ""
Write-Host "=== Recommendations ===" -ForegroundColor Blue

if ($driftLayers -gt 0) {
    Write-Host "WARNING: Drift detected in some layers. Please:" -ForegroundColor Yellow
    Write-Host "   1. Review terraform plan output for each layer in detail" -ForegroundColor Gray
    Write-Host "   2. Check for unexpected changes" -ForegroundColor Gray
    Write-Host "   3. Perform additional Import or code fixes as needed" -ForegroundColor Gray
}

if ($errorLayers -gt 0) {
    Write-Host "ERROR: Some layers have errors. Please check:" -ForegroundColor Red
    Write-Host "   1. Terraform configuration file syntax errors" -ForegroundColor Gray
    Write-Host "   2. AWS credentials and permissions" -ForegroundColor Gray
    Write-Host "   3. Backend configuration and state file access" -ForegroundColor Gray
}

if ($cleanLayers -eq $totalLayers) {
    Write-Host "SUCCESS: All layers are in clean state!" -ForegroundColor Green
    Write-Host "   Terraform state and actual AWS resources are fully synchronized." -ForegroundColor Gray
}

return $validationResults