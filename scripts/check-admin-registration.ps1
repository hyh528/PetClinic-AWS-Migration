# Script to check registered services in Spring Boot Admin
# This is a PowerShell script for Windows

$adminUrl = "http://petclinic-dev-alb-1211424104.us-west-2.elb.amazonaws.com/admin"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Checking Admin UI Service Registration" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

try {
    # Get all registered instances
    $instances = Invoke-RestMethod -Uri "$adminUrl/instances" -Method Get -ErrorAction Stop
    
    if ($instances.Count -eq 0) {
        Write-Host "No services are currently registered." -ForegroundColor Yellow
    } else {
        Write-Host "Registered Services: $($instances.Count)" -ForegroundColor Green
        Write-Host ""
        
        foreach ($instance in $instances) {
            Write-Host "Service: $($instance.registration.name)" -ForegroundColor Cyan
            Write-Host "  Instance ID: $($instance.id)" -ForegroundColor Gray
            Write-Host "  Status: $($instance.statusInfo.status)" -ForegroundColor $(
                switch ($instance.statusInfo.status) {
                    "UP" { "Green" }
                    "DOWN" { "Red" }
                    "OUT_OF_SERVICE" { "Yellow" }
                    "UNKNOWN" { "Gray" }
                    default { "Gray" }
                }
            )
            Write-Host "  Health URL: $($instance.registration.healthUrl)" -ForegroundColor Gray
            Write-Host "  Service URL: $($instance.registration.serviceUrl)" -ForegroundColor Gray
            Write-Host "  Management URL: $($instance.registration.managementUrl)" -ForegroundColor Gray
            Write-Host ""
        }
    }
    
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Admin UI URL: $adminUrl" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
}
catch {
    Write-Host "Failed to retrieve registration status" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Make sure the admin server is running and accessible at:" -ForegroundColor Yellow
    Write-Host "  $adminUrl" -ForegroundColor Yellow
}