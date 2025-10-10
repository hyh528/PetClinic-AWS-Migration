package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestIamModule(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../",

		Vars: map[string]interface{}{
			"project_name": "test-petclinic",
			"team_members": []string{"testuser1", "testuser2"},
		},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// 그룹 검증
	groupName := terraform.Output(t, terraformOptions, "group_name")
	assert.Contains(t, groupName, "test-petclinic", "Group name should contain project name")

	// 사용자 검증
	userNames := terraform.OutputList(t, terraformOptions, "user_names")
	assert.Len(t, userNames, 2, "Should have 2 users")
	assert.Contains(t, userNames, "test-petclinic-testuser1", "Should contain first user")
	assert.Contains(t, userNames, "test-petclinic-testuser2", "Should contain second user")

	// 그룹 멤버십 검증
	groupUsers := terraform.OutputList(t, terraformOptions, "group_users")
	assert.Len(t, groupUsers, 2, "Group should have 2 users")

	// 정책 첨부 검증 (AdministratorAccess)
	policyArn := terraform.Output(t, terraformOptions, "attached_policy_arn")
	assert.Equal(t, "arn:aws:iam::aws:policy/AdministratorAccess", policyArn, "Should have AdministratorAccess policy")
}
