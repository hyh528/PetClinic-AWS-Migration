# Import script for 07-application layer manual resources
# Import manually created security group rules and IAM policies

param(
    [string]$Region = "us-west-2",
    [string]$Profile = "petclinic-dev",
    [switch]$DryRun = $false
)

Write-Host "=== 07-application Layer Resource Import ===" -ForegroundColor Green
Write-Host "Region: $Region" -ForegroundColor Yellow
Write-Host "Profile: $Profile" -ForegroundColor Yellow
Write-Host "Dry Run: $DryRun" -ForegroundColor Yellow
Write-Host ""

# Change to 07-application layer directory
Push-Location "terraform/layers/07-application"

try {
    # Initialize Terraform if needed
    if (-not (Test-Path ".terraform")) {
        Write-Host "Initializing Terraform..." -ForegroundColor Yellow
        terraform init -backend-config=backend.config
    }

    Write-Host "1. Analyzing Current State" -ForegroundColor Magenta
    
    # Check current state
    Write-Host "  Current Terraform resources:" -ForegroundColor Yellow
    $currentState = terraform state list 2>$null
    Write-Host "    Total resources: $($currentState.Count)" -ForegroundColor Gray
    
    Write-Host ""
    Write-Host "2. Identifying Manual Resources to Import" -ForegroundColor Magenta
    
    # Manual resources identified from analysis
    $manualResources = @{
        "ECS Security Group Rules" = @{
            "sg-02ead082980491162_ingress_tcp_8080_8080_sg-0db313ea8f417da74" = "ECS SG - ALB access port 8080 (NEEDED)"
        }
        "Legacy Security Group Rules (TO BE REMOVED)" = @{
            "sg-02ead082980491162_ingress_tcp_8081_8081_sg-0db313ea8f417da74" = "ECS SG - ALB access port 8081 (LEGACY)"
            "sg-02ead082980491162_ingress_tcp_8082_8082_sg-0db313ea8f417da74" = "ECS SG - ALB access port 8082 (LEGACY)"
            "sg-02ead082980491162_ingress_tcp_8083_8083_sg-0db313ea8f417da74" = "ECS SG - ALB access port 8083 (LEGACY)"
        }
        "Aurora Security Group Rules" = @{
            "sg-063f135e0be9152d5_ingress_tcp_3306_3306_sg-02ead082980491162" = "Aurora SG - ECS access"
            "sg-063f135e0be9152d5_ingress_tcp_3306_3306_sg-0106687a95c375d3e" = "Aurora SG - Debug instance access"
        }
        "IAM Policies" = @{
            "arn:aws:iam::897722691159:policy/petclinic-ecs-db-secret-access-policy" = "DB Secret Access Policy"
            "arn:aws:iam::897722691159:policy/petclinic-ecs-secrets-policy-v2" = "Secrets Policy v2"
            "arn:aws:iam::897722691159:policy/petclinic-ecs-ssm-access-policy" = "SSM Access Policy"
        }
    }
    
    foreach ($category in $manualResources.Keys) {
        Write-Host "  $category:" -ForegroundColor Yellow
        foreach ($resource in $manualResources[$category].Keys) {
            Write-Host "    - $resource" -ForegroundColor Gray
            Write-Host "      Description: $($manualResources[$category][$resource])" -ForegroundColor DarkGray
        }
        Write-Host ""
    }
    
    Write-Host "3. Import Strategy" -ForegroundColor Magenta
    Write-Host "  Phase 1: Security Group Rules (High Priority)" -ForegroundColor Yellow
    Write-Host "  Phase 2: IAM Policies (Medium Priority)" -ForegroundColor Yellow
    Write-Host "  Phase 3: Validation and Cleanup" -ForegroundColor Yellow
    Write-Host ""
    
    if ($DryRun) {
        Write-Host "DRY RUN MODE - No actual imports will be performed" -ForegroundColor Cyan
        Write-Host ""
        
        Write-Host "Would import the following resources:" -ForegroundColor Cyan
        Write-Host "1. ECS Security Group ingress rule (1 rule for port 8080)" -ForegroundColor Gray
        Write-Host "2. Aurora Security Group ingress rules (2 rules)" -ForegroundColor Gray
        Write-Host "3. IAM policies attached to ECS execution role (3 policies)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Would REMOVE the following legacy resources:" -ForegroundColor Red
        Write-Host "1. ECS Security Group legacy rules (ports 8081, 8082, 8083)" -ForegroundColor Gray
        
    } else {
        Write-Host "IMPORTANT: This script identifies manual resources but does not perform imports." -ForegroundColor Red
        Write-Host "Manual imports require:" -ForegroundColor Yellow
        Write-Host "1. Adding resource definitions to Terraform code" -ForegroundColor Gray
        Write-Host "2. Running terraform import commands" -ForegroundColor Gray
        Write-Host "3. Verifying with terraform plan" -ForegroundColor Gray
        Write-Host ""
        
        Write-Host "Next Steps:" -ForegroundColor Magenta
        Write-Host "1. GOOD NEWS: Port 8080 rule already exists in 02-security layer!" -ForegroundColor Green
        Write-Host "2. Remove legacy port rules (8081, 8082, 8083) from AWS manually" -ForegroundColor Yellow
        Write-Host "3. Review IAM policies and add them to the security layer" -ForegroundColor Yellow
        Write-Host "4. Verify with terraform plan that no drift exists" -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host "4. Recommended Terraform Code Updates" -ForegroundColor Magenta
    
    Write-Host "  Security Group Rules (add to 02-security layer):" -ForegroundColor Yellow
    Write-Host @"
    # ECS Security Group - ALB access rules
    resource "aws_vpc_security_group_ingress_rule" "ecs_alb_8080" {
      security_group_id            = var.ecs_security_group_id
      referenced_security_group_id = var.alb_security_group_id
      from_port                    = 8080
      to_port                      = 8080
      ip_protocol                  = "tcp"
      description                  = "ALB to ECS port 8080"
    }
    
    # Similar rules for ports 8081, 8082, 8083
"@ -ForegroundColor Gray
    
    Write-Host ""
    Write-Host "  IAM Policies (add to 02-security layer):" -ForegroundColor Yellow
    Write-Host @"
    # Additional ECS task execution role policies
    resource "aws_iam_role_policy_attachment" "ecs_db_secret_access" {
      role       = aws_iam_role.ecs_task_execution.name
      policy_arn = aws_iam_policy.db_secret_access.arn
    }
"@ -ForegroundColor Gray

} catch {
    Write-Host "Error during analysis: $($_.Exception.Message)" -ForegroundColor Red
} finally {
    Pop-Location
}

Write-Host ""
Write-Host "=== Analysis Complete ===" -ForegroundColor Green
Write-Host "Manual resources identified and import strategy prepared." -ForegroundColor Cyan