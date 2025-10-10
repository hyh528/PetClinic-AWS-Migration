package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestCloudMapModule(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../",

		Vars: map[string]interface{}{
			"name_prefix": "test-petclinic",
			"environment": "test",
			"vpc_id":      "vpc-12345",
			"services": map[string]interface{}{
				"customers": map[string]interface{}{
					"port":              8080,
					"health_check_path": "/actuator/health",
				},
				"vets": map[string]interface{}{
					"port":              8080,
					"health_check_path": "/actuator/health",
				},
			},
			"tags": map[string]string{
				"Project":     "petclinic",
				"Environment": "test",
			},
		},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// 네임스페이스 검증
	namespaceId := terraform.Output(t, terraformOptions, "namespace_id")
	assert.NotEmpty(t, namespaceId, "Namespace ID should not be empty")

	namespaceArn := terraform.Output(t, terraformOptions, "namespace_arn")
	assert.NotEmpty(t, namespaceArn, "Namespace ARN should not be empty")

	// 서비스 검증
	serviceIds := terraform.OutputList(t, terraformOptions, "service_ids")
	assert.Len(t, serviceIds, 2, "Should have 2 services")

	serviceArns := terraform.OutputList(t, terraformOptions, "service_arns")
	assert.Len(t, serviceArns, 2, "Should have 2 service ARNs")

	// 서비스 이름 검증
	serviceNames := terraform.OutputList(t, terraformOptions, "service_names")
	assert.Contains(t, serviceNames, "customers", "Should contain customers service")
	assert.Contains(t, serviceNames, "vets", "Should contain vets service")
}
