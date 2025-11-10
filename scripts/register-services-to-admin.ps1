# Script to manually register services to Spring Boot Admin
# This is a PowerShell script for Windows

$adminUrl = "http://petclinic-dev-alb-1211424104.us-west-2.elb.amazonaws.com/admin"
$albDns = "petclinic-dev-alb-1211424104.us-west-2.elb.amazonaws.com"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Manual Service Registration to Admin UI" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Define services to register
$services = @(
    @{
        name = "customers-service"
        path = "api/customers"
    },
    @{
        name = "vets-service"
        path = "api/vets"
    },
    @{
        name = "visits-service"
        path = "api/visits"
    }
)

$registeredCount = 0
$failedCount = 0

foreach ($service in $services) {
    Write-Host "Registering $($service.name)..." -ForegroundColor Yellow
    
    # Create registration payload
    $payload = @{
        name = $service.name
        managementUrl = "http://$albDns/$($service.path)/actuator"
        healthUrl = "http://$albDns/$($service.path)/actuator/health"
        serviceUrl = "http://$albDns/$($service.path)/"
    } | ConvertTo-Json
    
    Write-Host "  Payload: $payload" -ForegroundColor Gray
    
    try {
        # Register the service
        $response = Invoke-RestMethod -Uri "$adminUrl/instances" `
            -Method Post `
            -Body $payload `
            -ContentType "application/json" `
            -ErrorAction Stop
        
        Write-Host "  ✓ Successfully registered $($service.name)" -ForegroundColor Green
        Write-Host "    Instance ID: $($response.id)" -ForegroundColor Gray
        $registeredCount++
    }
    catch {
        Write-Host "  ✗ Failed to register $($service.name)" -ForegroundColor Red
        Write-Host "    Error: $($_.Exception.Message)" -ForegroundColor Red
        $failedCount++
    }
    
    Write-Host ""
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Registration Summary:" -ForegroundColor Cyan
Write-Host "  Successfully registered: $registeredCount" -ForegroundColor $(if ($registeredCount -gt 0) { "Green" } else { "Gray" })
Write-Host "  Failed: $failedCount" -ForegroundColor $(if ($failedCount -gt 0) { "Red" } else { "Gray" })
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Check the admin UI at: $adminUrl" -ForegroundColor Cyan