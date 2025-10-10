package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestEcsModule(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../",

		Vars: map[string]interface{}{
			"name_prefix":            "test-petclinic",
			"environment":            "test",
			"vpc_id":                 "vpc-12345",
			"private_app_subnet_ids": []string{"subnet-12345", "subnet-67890"},
			"alb_security_group_id":  "sg-alb123",
			"ecs_security_group_id":  "sg-ecs123",
			"target_group_arn":       "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/test-tg/1234567890123456",
			"container_image":        "nginx:latest",
			"container_port":         80,
			"desired_count":          2,
			"tags": map[string]string{
				"Project":     "petclinic",
				"Environment": "test",
			},
		},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// ECS 클러스터 검증
	clusterName := terraform.Output(t, terraformOptions, "ecs_cluster_name")
	assert.Contains(t, clusterName, "test-petclinic", "Cluster name should contain name prefix")

	// ECS 서비스 검증
	serviceName := terraform.Output(t, terraformOptions, "ecs_service_name")
	assert.Contains(t, serviceName, "test-petclinic", "Service name should contain name prefix")

	// 태스크 정의 검증
	taskDefinitionArn := terraform.Output(t, terraformOptions, "task_definition_arn")
	assert.NotEmpty(t, taskDefinitionArn, "Task definition ARN should not be empty")

	// 실행 역할 검증
	executionRoleArn := terraform.Output(t, terraformOptions, "execution_role_arn")
	assert.NotEmpty(t, executionRoleArn, "Execution role ARN should not be empty")

	// 태스크 역할 검증
	taskRoleArn := terraform.Output(t, terraformOptions, "task_role_arn")
	assert.NotEmpty(t, taskRoleArn, "Task role ARN should not be empty")
}
