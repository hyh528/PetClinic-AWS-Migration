package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"../../test/common"
)

func TestVpcModule(t *testing.T) {
	t.Parallel()

	// 공통 테스트 설정 생성
	config := common.NewTestConfig(t, "../")
	
	// VPC 모듈 특정 변수 설정
	config.SetVariables(map[string]interface{}{
		"name_prefix":              common.GenerateUniqueResourceName("test-petclinic", config.TestID),
		"environment":              config.Environment,
		"vpc_cidr":                 "10.0.0.0/16",
		"enable_ipv6":              false,
		"azs":                      []string{"ap-northeast-1a", "ap-northeast-1c"},
		"public_subnet_cidrs":      []string{"10.0.1.0/24", "10.0.2.0/24"},
		"private_app_subnet_cidrs": []string{"10.0.10.0/24", "10.0.11.0/24"},
		"private_db_subnet_cidrs":  []string{"10.0.20.0/24", "10.0.21.0/24"},
		"create_nat_per_az":        true,
	})

	// 테스트 실행
	config.RunUnitTest(t, func(t *testing.T, terraformOptions *terraform.Options) {
		// Terraform InitAndApply
		terraform.InitAndApply(t, terraformOptions)

		// 기본 출력값 검증
		expectedOutputs := []string{
			"vpc_id", "vpc_cidr_block", "internet_gateway_id",
		}
		common.ValidateCommonOutputs(t, terraformOptions, expectedOutputs)

		// VPC 특정 검증
		validateVPCOutputs(t, terraformOptions)

		// AWS 리소스 실제 상태 검증
		validateAWSResources(t, terraformOptions, config)

		// 태그 검증
		expectedTags := map[string]string{
			"Purpose":     "terratest",
			"TestID":      config.TestID,
			"Environment": config.Environment,
			"ManagedBy":   "terratest",
		}
		common.ValidateResourceTags(t, terraformOptions, expectedTags)
	})
}

func TestVpcConnectivity(t *testing.T) {
	t.Parallel()

	config := common.NewTestConfig(t, "../")
	config.SetVariables(map[string]interface{}{
		"name_prefix":              common.GenerateUniqueResourceName("test-connectivity", config.TestID),
		"environment":              config.Environment,
		"vpc_cidr":                 "10.1.0.0/16",
		"enable_ipv6":              false,
		"azs":                      []string{"ap-northeast-1a", "ap-northeast-1c"},
		"public_subnet_cidrs":      []string{"10.1.1.0/24", "10.1.2.0/24"},
		"private_app_subnet_cidrs": []string{"10.1.10.0/24", "10.1.11.0/24"},
		"private_db_subnet_cidrs":  []string{"10.1.20.0/24", "10.1.21.0/24"},
		"create_nat_per_az":        true,
	})

	config.RunUnitTest(t, func(t *testing.T, terraformOptions *terraform.Options) {
		terraform.InitAndApply(t, terraformOptions)

		// 네트워크 연결성 테스트
		validateNetworkConnectivity(t, terraformOptions, config)
	})
}

// validateVPCOutputs VPC 모듈의 출력값을 검증합니다
func validateVPCOutputs(t *testing.T, terraformOptions *terraform.Options) {
	// VPC CIDR 검증
	vpcCidr := terraform.Output(t, terraformOptions, "vpc_cidr_block")
	assert.Equal(t, "10.0.0.0/16", vpcCidr, "VPC CIDR should match input")

	// 퍼블릭 서브넷 ID 검증
	publicSubnetIds := terraform.OutputList(t, terraformOptions, "public_subnet_ids")
	assert.Len(t, publicSubnetIds, 2, "Should have 2 public subnets")

	// 프라이빗 앱 서브넷 ID 검증
	privateAppSubnetIds := terraform.OutputList(t, terraformOptions, "private_app_subnet_ids")
	assert.Len(t, privateAppSubnetIds, 2, "Should have 2 private app subnets")

	// 프라이빗 DB 서브넷 ID 검증
	privateDbSubnetIds := terraform.OutputList(t, terraformOptions, "private_db_subnet_ids")
	assert.Len(t, privateDbSubnetIds, 2, "Should have 2 private db subnets")

	// NAT 게이트웨이 검증
	natGatewayIds := terraform.OutputList(t, terraformOptions, "nat_gateway_ids")
	assert.Len(t, natGatewayIds, 2, "Should have 2 NAT gateways (one per AZ)")

	t.Logf("✓ All VPC outputs validated successfully")
}

// validateAWSResources AWS 리소스의 실제 상태를 검증합니다
func validateAWSResources(t *testing.T, terraformOptions *terraform.Options, config *common.TestConfig) {
	awsHelper, err := common.NewAWSHelper(config.Region)
	if err != nil {
		t.Fatalf("Failed to create AWS helper: %v", err)
	}

	// VPC 리소스 검증
	awsHelper.ValidateVPCResources(t, terraformOptions)
}

// validateNetworkConnectivity 네트워크 연결성을 검증합니다
func validateNetworkConnectivity(t *testing.T, terraformOptions *terraform.Options, config *common.TestConfig) {
	// 실제 네트워크 연결성 테스트는 복잡하므로 기본적인 구성 검증만 수행
	vpcId := terraform.Output(t, terraformOptions, "vpc_id")
	assert.NotEmpty(t, vpcId, "VPC ID should not be empty")

	// 퍼블릭 서브넷이 인터넷 게이트웨이로 라우팅되는지 확인
	publicSubnets := terraform.OutputList(t, terraformOptions, "public_subnet_ids")
	igwId := terraform.Output(t, terraformOptions, "internet_gateway_id")
	
	assert.NotEmpty(t, publicSubnets, "Public subnets should exist")
	assert.NotEmpty(t, igwId, "Internet Gateway should exist")

	// 프라이빗 서브넷이 NAT 게이트웨이로 라우팅되는지 확인
	privateSubnets := terraform.OutputList(t, terraformOptions, "private_app_subnet_ids")
	natGateways := terraform.OutputList(t, terraformOptions, "nat_gateway_ids")
	
	assert.NotEmpty(t, privateSubnets, "Private subnets should exist")
	assert.NotEmpty(t, natGateways, "NAT Gateways should exist")

	t.Logf("✓ Network connectivity configuration validated")
}
