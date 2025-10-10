package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestVpcModule(t *testing.T) {
	t.Parallel()

	// Terraform 옵션 설정
	terraformOptions := &terraform.Options{
		TerraformDir: "../", // 모듈 디렉토리 상대 경로

		Vars: map[string]interface{}{
			"name_prefix":              "test-petclinic",
			"environment":              "test",
			"vpc_cidr":                 "10.0.0.0/16",
			"enable_ipv6":              false,
			"azs":                      []string{"us-east-1a", "us-east-1b"},
			"public_subnet_cidrs":      []string{"10.0.1.0/24", "10.0.2.0/24"},
			"private_app_subnet_cidrs": []string{"10.0.10.0/24", "10.0.11.0/24"},
			"private_db_subnet_cidrs":  []string{"10.0.20.0/24", "10.0.21.0/24"},
			"create_nat_per_az":        true,
			"tags": map[string]string{
				"Project":     "petclinic",
				"Environment": "test",
			},
		},
	}

	// Terraform Destroy를 defer로 설정하여 테스트 후 정리
	defer terraform.Destroy(t, terraformOptions)

	// Terraform InitAndApply
	terraform.InitAndApply(t, terraformOptions)

	// 출력 값 검증
	vpcId := terraform.Output(t, terraformOptions, "vpc_id")
	assert.NotEmpty(t, vpcId, "VPC ID should not be empty")

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

	// 인터넷 게이트웨이 검증
	igwId := terraform.Output(t, terraformOptions, "internet_gateway_id")
	assert.NotEmpty(t, igwId, "Internet Gateway ID should not be empty")
}
