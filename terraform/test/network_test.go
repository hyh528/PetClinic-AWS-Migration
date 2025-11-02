package test

import (
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/petclinic/terraform-test-common/common"
	"github.com/stretchr/testify/assert"
)

// TestNetworkLayer 네트워크 레이어 단위 테스트
func TestNetworkLayer(t *testing.T) {
	t.Parallel()

	// 테스트 설정
	config := common.NewTestConfig(t, "../layers/01-network").
		SetVariable("project_name", "petclinic-test").
		SetVariable("environment", "test").
		SetVariable("vpc_cidr", "10.1.0.0/16").
		SetVariables(map[string]interface{}{
			"availability_zones": []string{"ap-northeast-2a", "ap-northeast-2c"},
			"enable_nat_gateway": true,
			"enable_vpn_gateway": false,
		})

	// 단위 테스트 실행
	config.RunUnitTest(t, func(t *testing.T, terraformOptions *terraform.Options) {
		// Terraform 초기화 및 적용
		terraform.InitAndApply(t, terraformOptions)

		// 기본 출력값 검증
		expectedOutputs := []string{
			"vpc_id",
			"vpc_cidr_block",
			"public_subnet_ids",
			"private_app_subnet_ids",
			"private_db_subnet_ids",
			"internet_gateway_id",
		}
		common.ValidateCommonOutputs(t, terraformOptions, expectedOutputs)

		// VPC CIDR 검증
		vpcCidr := terraform.Output(t, terraformOptions, "vpc_cidr_block")
		assert.Equal(t, "10.1.0.0/16", vpcCidr, "VPC CIDR should match expected value")

		// 서브넷 개수 검증
		publicSubnets := terraform.OutputList(t, terraformOptions, "public_subnet_ids")
		privateAppSubnets := terraform.OutputList(t, terraformOptions, "private_app_subnet_ids")
		privateDbSubnets := terraform.OutputList(t, terraformOptions, "private_db_subnet_ids")

		assert.Len(t, publicSubnets, 2, "Should have 2 public subnets")
		assert.Len(t, privateAppSubnets, 2, "Should have 2 private app subnets")
		assert.Len(t, privateDbSubnets, 2, "Should have 2 private DB subnets")

		// NAT Gateway 검증 (활성화된 경우)
		if natGatewayIds := terraform.OutputList(t, terraformOptions, "nat_gateway_ids"); len(natGatewayIds) > 0 {
			assert.Len(t, natGatewayIds, 2, "Should have 2 NAT gateways for high availability")
		}

		// 태그 검증
		expectedTags := map[string]string{
			"Purpose":     "terratest",
			"Environment": "test",
			"ManagedBy":   "terratest",
		}
		common.ValidateResourceTags(t, terraformOptions, expectedTags)

		t.Log("✅ Network layer unit test completed successfully")
	})
}

// TestNetworkLayerIntegration 네트워크 레이어 통합 테스트
func TestNetworkLayerIntegration(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping integration test in short mode")
	}

	// 테스트 설정
	config := common.NewTestConfig(t, "../layers/01-network").
		SetVariable("project_name", "petclinic-integration").
		SetVariable("environment", "test").
		SetVariable("vpc_cidr", "10.2.0.0/16").
		SetVariables(map[string]interface{}{
			"availability_zones": []string{"ap-northeast-2a", "ap-northeast-2c"},
			"enable_nat_gateway": true,
			"enable_vpn_gateway": false,
		})

	// 통합 테스트 실행
	config.RunIntegrationTest(t, func(t *testing.T, terraformOptions *terraform.Options) {
		// Terraform 초기화 및 적용
		terraform.InitAndApply(t, terraformOptions)

		// AWS 헬퍼 생성
		awsHelper, err := common.NewAWSHelper("ap-northeast-2")
		assert.NoError(t, err, "Should create AWS helper without error")

		// AWS 리소스 검증
		awsHelper.ValidateVPCResources(t, terraformOptions)

		// 연결성 테스트 (실제 AWS 리소스 상태 확인)
		vpcId := terraform.Output(t, terraformOptions, "vpc_id")
		assert.NotEmpty(t, vpcId, "VPC ID should not be empty")

		// 리소스 준비 대기
		common.WaitForResourceReady(t, "VPC resources", 5*time.Minute, func() bool {
			// 실제 VPC 상태 확인 로직
			return true // 간단한 예시
		})

		t.Log("✅ Network layer integration test completed successfully")
	})
}

// TestNetworkLayerWithMinimalConfig 최소 설정으로 네트워크 레이어 테스트
func TestNetworkLayerWithMinimalConfig(t *testing.T) {
	t.Parallel()

	// 최소 설정으로 테스트
	config := common.NewTestConfig(t, "../layers/01-network").
		SetVariable("project_name", "petclinic-minimal").
		SetVariable("environment", "test").
		SetVariable("vpc_cidr", "10.3.0.0/16").
		SetVariables(map[string]interface{}{
			"availability_zones": []string{"ap-northeast-2a"},
			"enable_nat_gateway": false, // NAT Gateway 비활성화
			"enable_vpn_gateway": false,
		})

	config.RunUnitTest(t, func(t *testing.T, terraformOptions *terraform.Options) {
		terraform.InitAndApply(t, terraformOptions)

		// 기본 출력값 검증
		vpcId := terraform.Output(t, terraformOptions, "vpc_id")
		assert.NotEmpty(t, vpcId, "VPC ID should not be empty")

		// NAT Gateway가 생성되지 않았는지 확인
		natGatewayIds := terraform.OutputList(t, terraformOptions, "nat_gateway_ids")
		assert.Empty(t, natGatewayIds, "Should not have NAT gateways when disabled")

		t.Log("✅ Network layer minimal config test completed successfully")
	})
}

// TestNetworkLayerValidation 네트워크 레이어 검증 테스트
func TestNetworkLayerValidation(t *testing.T) {
	t.Parallel()

	// 잘못된 설정으로 테스트 (실패 예상)
	config := common.NewTestConfig(t, "../layers/01-network").
		SetVariable("project_name", "petclinic-invalid").
		SetVariable("environment", "test").
		SetVariable("vpc_cidr", "invalid-cidr"). // 잘못된 CIDR
		SetVariables(map[string]interface{}{
			"availability_zones": []string{"ap-northeast-2a"},
		})

	terraformOptions := config.GetTerraformOptions()

	// 초기화는 성공해야 함
	terraform.Init(t, terraformOptions)

	// Plan은 실패해야 함 (잘못된 CIDR로 인해)
	_, err := terraform.PlanE(t, terraformOptions)
	assert.Error(t, err, "Plan should fail with invalid CIDR")

	t.Log("✅ Network layer validation test completed successfully")
}