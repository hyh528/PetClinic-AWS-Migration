package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestLambdaGenaiModule(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../",

		Vars: map[string]interface{}{
			"name_prefix":    "test-petclinic",
			"environment":    "test",
			"lambda_runtime": "python3.9",
			"lambda_timeout": 30,
			"memory_size":    256,
			"tags": map[string]string{
				"Project":     "petclinic",
				"Environment": "test",
			},
		},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Lambda 함수 검증
	functionName := terraform.Output(t, terraformOptions, "lambda_function_name")
	assert.Contains(t, functionName, "test-petclinic", "Function name should contain name prefix")

	// Lambda 함수 ARN 검증
	functionArn := terraform.Output(t, terraformOptions, "lambda_function_arn")
	assert.NotEmpty(t, functionArn, "Function ARN should not be empty")
	assert.Contains(t, functionArn, "arn:aws:lambda", "Function ARN should be valid Lambda ARN")

	// IAM 역할 검증
	roleArn := terraform.Output(t, terraformOptions, "lambda_role_arn")
	assert.NotEmpty(t, roleArn, "Role ARN should not be empty")
	assert.Contains(t, roleArn, "arn:aws:iam", "Role ARN should be valid IAM ARN")

	// CloudWatch 로그 그룹 검증
	logGroupName := terraform.Output(t, terraformOptions, "lambda_log_group_name")
	assert.Contains(t, logGroupName, "/aws/lambda/test-petclinic", "Log group name should contain function name")

	// Lambda 함수 URL 검증 (있는 경우)
	functionUrl := terraform.Output(t, terraformOptions, "lambda_function_url")
	if functionUrl != "" {
		assert.Contains(t, functionUrl, "https://", "Function URL should be HTTPS")
	}
}
