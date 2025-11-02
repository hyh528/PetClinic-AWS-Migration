# Fix 07-application layer security group rules
# Add missing ALB to ECS port rules in the application layer

Write-Host "=== Fixing 07-application Security Group Rules ===" -ForegroundColor Green
Write-Host ""

Write-Host "Current Issue Analysis:" -ForegroundColor Yellow
Write-Host "- 02-security layer only creates rule for port 8080" -ForegroundColor Gray
Write-Host "- Missing rules for ports 8081, 8082, 8083" -ForegroundColor Gray
Write-Host "- These were manually created and need to be managed by Terraform" -ForegroundColor Gray
Write-Host ""

Write-Host "Recommended Solution:" -ForegroundColor Magenta
Write-Host "Add additional security group rules in 07-application layer" -ForegroundColor Yellow
Write-Host ""

$terraformCode = @"
# Add to terraform/layers/07-application/main.tf

# Additional ALB to ECS security group rules for service-specific ports
resource "aws_vpc_security_group_ingress_rule" "ecs_alb_customers" {
  security_group_id            = data.terraform_remote_state.security.outputs.ecs_security_group_id
  referenced_security_group_id = data.terraform_remote_state.security.outputs.alb_security_group_id
  from_port                    = 8081
  to_port                      = 8081
  ip_protocol                  = "tcp"
  description                  = "ALB to ECS customers service port"
}

resource "aws_vpc_security_group_ingress_rule" "ecs_alb_visits" {
  security_group_id            = data.terraform_remote_state.security.outputs.ecs_security_group_id
  referenced_security_group_id = data.terraform_remote_state.security.outputs.alb_security_group_id
  from_port                    = 8082
  to_port                      = 8082
  ip_protocol                  = "tcp"
  description                  = "ALB to ECS visits service port"
}

resource "aws_vpc_security_group_ingress_rule" "ecs_alb_vets" {
  security_group_id            = data.terraform_remote_state.security.outputs.ecs_security_group_id
  referenced_security_group_id = data.terraform_remote_state.security.outputs.alb_security_group_id
  from_port                    = 8083
  to_port                      = 8083
  ip_protocol                  = "tcp"
  description                  = "ALB to ECS vets service port"
}
"@

Write-Host "Terraform Code to Add:" -ForegroundColor Cyan
Write-Host $terraformCode -ForegroundColor Gray
Write-Host ""

Write-Host "Why This Approach is Better:" -ForegroundColor Magenta
Write-Host "✅ Follows Terraform best practices" -ForegroundColor Green
Write-Host "✅ Application layer owns application-specific rules" -ForegroundColor Green
Write-Host "✅ Security layer provides base security groups" -ForegroundColor Green
Write-Host "✅ Clear separation of concerns" -ForegroundColor Green
Write-Host "✅ Easier to maintain and understand" -ForegroundColor Green
Write-Host ""

Write-Host "Alternative Approaches (NOT recommended):" -ForegroundColor Yellow
Write-Host "❌ Add all ports to 02-security: Violates separation of concerns" -ForegroundColor Red
Write-Host "❌ Use enable_alb_integration flag: Creates complex conditional logic" -ForegroundColor Red
Write-Host "❌ Keep manual rules: Defeats purpose of Infrastructure as Code" -ForegroundColor Red
Write-Host ""

Write-Host "Implementation Steps:" -ForegroundColor Magenta
Write-Host "1. Add the security group rules to 07-application/main.tf" -ForegroundColor Yellow
Write-Host "2. Import existing manual rules using terraform import" -ForegroundColor Yellow
Write-Host "3. Run terraform plan to verify no changes" -ForegroundColor Yellow
Write-Host "4. Document the pattern for future services" -ForegroundColor Yellow
Write-Host ""

Write-Host "=== Analysis Complete ===" -ForegroundColor Green