package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestAlbModule(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../",

		Vars: map[string]interface{}{
			"name_prefix":           "test-petclinic",
			"environment":           "test",
			"vpc_id":                "vpc-12345",
			"public_subnet_ids":     []string{"subnet-12345", "subnet-67890"},
			"alb_security_group_id": "sg-alb123",
			"target_group_port":     8080,
			"health_check_path":     "/actuator/health",
			"tags": map[string]string{
				"Project":     "petclinic",
				"Environment": "test",
			},
		},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// ALB 검증
	albArn := terraform.Output(t, terraformOptions, "alb_arn")
	assert.NotEmpty(t, albArn, "ALB ARN should not be empty")

	albDnsName := terraform.Output(t, terraformOptions, "alb_dns_name")
	assert.NotEmpty(t, albDnsName, "ALB DNS name should not be empty")

	// 타겟 그룹 검증
	targetGroupArn := terraform.Output(t, terraformOptions, "target_group_arn")
	assert.NotEmpty(t, targetGroupArn, "Target group ARN should not be empty")

	// 리스너 검증
	listenerArn := terraform.Output(t, terraformOptions, "listener_arn")
	assert.NotEmpty(t, listenerArn, "Listener ARN should not be empty")

	// 보안 그룹 연결 검증
	albSgId := terraform.Output(t, terraformOptions, "alb_security_group_id")
	assert.NotEmpty(t, albSgId, "ALB security group ID should not be empty")
}
