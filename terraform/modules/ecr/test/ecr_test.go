package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestEcrModule(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../",

		Vars: map[string]interface{}{
			"name_prefix":          "test-petclinic",
			"environment":          "test",
			"repositories":         []string{"customers", "vets", "visits"},
			"image_tag_mutability": "MUTABLE",
			"scan_on_push":         true,
			"tags": map[string]string{
				"Project":     "petclinic",
				"Environment": "test",
			},
		},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// 리포지토리 검증
	repositoryUrls := terraform.OutputList(t, terraformOptions, "repository_urls")
	assert.Len(t, repositoryUrls, 3, "Should have 3 repository URLs")

	repositoryArns := terraform.OutputList(t, terraformOptions, "repository_arns")
	assert.Len(t, repositoryArns, 3, "Should have 3 repository ARNs")

	// 리포지토리 이름 검증
	repositoryNames := terraform.OutputList(t, terraformOptions, "repository_names")
	assert.Contains(t, repositoryNames, "test-petclinic-customers", "Should contain customers repo")
	assert.Contains(t, repositoryNames, "test-petclinic-vets", "Should contain vets repo")
	assert.Contains(t, repositoryNames, "test-petclinic-visits", "Should contain visits repo")
}
