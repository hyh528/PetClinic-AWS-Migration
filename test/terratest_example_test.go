package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestExampleModule(t *testing.T) {
	// 병렬 실행 허용(필요시 비활성화)
	// t.Parallel()

	terraformDir := "../terraform/modules/example-bucket"

	options := &terraform.Options{
		TerraformDir: terraformDir,
		Vars: map[string]interface{}{
			"bucket_name": "terratest-example-12345",
		},
		EnvVars: map[string]string{
			"AWS_DEFAULT_REGION": "ap-southeast-2",
		},
	}

	defer terraform.Destroy(t, options)

	terraform.InitAndApply(t, options)

	out := terraform.Output(t, options, "bucket_id")
	assert.Contains(t, out, "terratest-example-")
}
