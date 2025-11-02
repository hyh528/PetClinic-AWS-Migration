package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/petclinic/terraform-test-common/common"
	"github.com/stretchr/testify/assert"
)

// TestSecurityLayer 보안 레이어 단위 테스트
func TestSecurityLayer(t *testing.T) {
	t.Parallel()

	// 네트워크 레이어 출력값 모킹 (실제 환경에서는 data source 사용)
	config := common.NewTestConfig(t, "../layers/02-security").
		SetVariable("project_name", "petclinic-test").
		SetVariable("environment", "test").
		SetVariables(map[string]interface{}{
			// 네트워크 레이어 의존성 (실제로는 data source로 가져옴)
			"vpc_id": "vpc-test123456",
			"private_app_subnet_ids": []string{"subnet-app1", "subnet-app2"},
			"private_db_subnet_ids":  []string{"subnet-db1", "subnet-db2"},
		})

	config.RunUnitTest(t, func(t *testing.T, terraformOptions *terraform.Options) {
		// Plan만 실행 (실제 리소스 생성 없이 검증)
		terraform.Init(t, terraformOptions)
		planOutput := terraform.Plan(t, terraformOptions)

		// Plan 출력에서 예상 리소스 확인
		assert.Contains(t, planOutput, "aws_security_group", "Should create security groups")
		assert.Contains(t, planOutput, "aws_iam_role", "Should create IAM roles")

		// 보안 그룹 개수 확인 (예상값)
		expectedSecurityGroups := []string{
			"alb_security_group",
			"ecs_security_group", 
			"aurora_security_group",
		}

		for _, sgName := range expectedSecurityGroups {
			assert.Contains(t, planOutput, sgName, "Should create %s", sgName)
		}

		t.Log("✅ Security layer unit test completed successfully")
	})
}

// TestSecurityLayerWithNetworkDependency 네트워크 의존성과 함께 보안 레이어 테스트
func TestSecurityLayerWithNetworkDependency(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping integration test in short mode")
	}

	// 먼저 네트워크 레이어 배포
	networkConfig := common.NewTestConfig(t, "../layers/01-network").
		SetVariable("project_name", "petclinic-sec-test").
		SetVariable("environment", "test").
		SetVariable("vpc_cidr", "10.4.0.0/16").
		SetVariables(map[string]interface{}{
			"availability_zones": []string{"ap-northeast-2a", "ap-northeast-2c"},
			"enable_nat_gateway": false,
		})

	networkConfig.RunIntegrationTest(t, func(t *testing.T, networkOptions *terraform.Options) {
		// 네트워크 레이어 배포
		terraform.InitAndApply(t, networkOptions)

		// 네트워크 출력값 가져오기
		vpcId := terraform.Output(t, networkOptions, "vpc_id")
		privateAppSubnets := terraform.OutputList(t, networkOptions, "private_app_subnet_ids")
		privateDbSubnets := terraform.OutputList(t, networkOptions, "private_db_subnet_ids")

		// 보안 레이어 설정
		securityConfig := common.NewTestConfig(t, "../layers/02-security").
			SetVariable("project_name", "petclinic-sec-test").
			SetVariable("environment", "test").
			SetVariables(map[string]interface{}{
				"vpc_id":                 vpcId,
				"private_app_subnet_ids": privateAppSubnets,
				"private_db_subnet_ids":  privateDbSubnets,
			})

		securityOptions := securityConfig.GetTerraformOptions()

		// 보안 레이어 배포
		terraform.InitAndApply(t, securityOptions)

		// 보안 그룹 출력값 검증
		expectedOutputs := []string{
			"alb_security_group_id",
			"ecs_security_group_id",
			"aurora_security_group_id",
		}
		common.ValidateCommonOutputs(t, securityOptions, expectedOutputs)

		// IAM 역할 출력값 검증
		ecsTaskRole := terraform.Output(t, securityOptions, "ecs_task_execution_role_arn")
		assert.NotEmpty(t, ecsTaskRole, "ECS task execution role should be created")

		// 보안 레이어 정리
		terraform.Destroy(t, securityOptions)

		t.Log("✅ Security layer with network dependency test completed successfully")
	})
}

// TestSecurityGroupRules 보안 그룹 규칙 테스트
func TestSecurityGroupRules(t *testing.T) {
	t.Parallel()

	config := common.NewTestConfig(t, "../layers/02-security").
		SetVariable("project_name", "petclinic-sg-test").
		SetVariable("environment", "test").
		SetVariables(map[string]interface{}{
			"vpc_id": "vpc-test123456",
			"private_app_subnet_ids": []string{"subnet-app1"},
			"private_db_subnet_ids":  []string{"subnet-db1"},
		})

	config.RunUnitTest(t, func(t *testing.T, terraformOptions *terraform.Options) {
		terraform.Init(t, terraformOptions)
		planOutput := terraform.Plan(t, terraformOptions)

		// ALB 보안 그룹 규칙 확인
		assert.Contains(t, planOutput, "from_port   = 80", "Should allow HTTP traffic")
		assert.Contains(t, planOutput, "from_port   = 443", "Should allow HTTPS traffic")

		// ECS 보안 그룹 규칙 확인
		assert.Contains(t, planOutput, "from_port   = 8080", "Should allow application port")

		// Aurora 보안 그룹 규칙 확인
		assert.Contains(t, planOutput, "from_port   = 3306", "Should allow MySQL port")

		t.Log("✅ Security group rules test completed successfully")
	})
}

// TestIAMRoles IAM 역할 테스트
func TestIAMRoles(t *testing.T) {
	t.Parallel()

	config := common.NewTestConfig(t, "../layers/02-security").
		SetVariable("project_name", "petclinic-iam-test").
		SetVariable("environment", "test").
		SetVariables(map[string]interface{}{
			"vpc_id": "vpc-test123456",
			"private_app_subnet_ids": []string{"subnet-app1"},
			"private_db_subnet_ids":  []string{"subnet-db1"},
		})

	config.RunUnitTest(t, func(t *testing.T, terraformOptions *terraform.Options) {
		terraform.Init(t, terraformOptions)
		planOutput := terraform.Plan(t, terraformOptions)

		// ECS 관련 IAM 역할 확인
		expectedIAMResources := []string{
			"aws_iam_role.ecs_task_execution_role",
			"aws_iam_role.ecs_task_role",
			"aws_iam_role_policy_attachment",
		}

		for _, resource := range expectedIAMResources {
			assert.Contains(t, planOutput, resource, "Should create %s", resource)
		}

		// 필수 정책 연결 확인
		assert.Contains(t, planOutput, "AmazonECSTaskExecutionRolePolicy", "Should attach ECS execution policy")

		t.Log("✅ IAM roles test completed successfully")
	})
}

// TestVPCEndpoints VPC 엔드포인트 테스트
func TestVPCEndpoints(t *testing.T) {
	t.Parallel()

	config := common.NewTestConfig(t, "../layers/02-security").
		SetVariable("project_name", "petclinic-vpc-endpoint-test").
		SetVariable("environment", "test").
		SetVariables(map[string]interface{}{
			"vpc_id": "vpc-test123456",
			"private_app_subnet_ids": []string{"subnet-app1", "subnet-app2"},
			"private_db_subnet_ids":  []string{"subnet-db1", "subnet-db2"},
			"enable_vpc_endpoints":   true,
		})

	config.RunUnitTest(t, func(t *testing.T, terraformOptions *terraform.Options) {
		terraform.Init(t, terraformOptions)
		planOutput := terraform.Plan(t, terraformOptions)

		// VPC 엔드포인트 확인
		expectedEndpoints := []string{
			"com.amazonaws.ap-northeast-2.ecr.dkr",
			"com.amazonaws.ap-northeast-2.ecr.api",
			"com.amazonaws.ap-northeast-2.logs",
			"com.amazonaws.ap-northeast-2.ssm",
		}

		for _, endpoint := range expectedEndpoints {
			assert.Contains(t, planOutput, endpoint, "Should create VPC endpoint for %s", endpoint)
		}

		t.Log("✅ VPC endpoints test completed successfully")
	})
}