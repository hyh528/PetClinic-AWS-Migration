package test

import (
	"fmt"
	"strings"
	"testing"
	"time"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/ec2"
	"github.com/aws/aws-sdk-go/service/iam"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/retry"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// TestSecurityModule - Security 모듈의 종합적인 테스트
func TestSecurityModule(t *testing.T) {
	t.Parallel()

	// 고유한 테스트 식별자 생성
	uniqueId := random.UniqueId()
	namePrefix := fmt.Sprintf("test-sec-%s", strings.ToLower(uniqueId))

	// 사전 요구사항: VPC 생성 (Mock 데이터 사용)
	testVpcId := createTestVPCForSecurity(t, uniqueId)
	defer deleteTestVPCForSecurity(t, testVpcId)

	// Security Terraform 옵션 설정
	terraformOptions := &terraform.Options{
		TerraformDir: "../",
		Vars: map[string]interface{}{
			"name_prefix":            namePrefix,
			"environment":            "test",
			"vpc_id":                 testVpcId,
			"alb_security_group_id":  "",
			"vpce_security_group_id": "",
			"ecs_task_port":          8080,
			"rds_port":               3306,
			"tags": map[string]string{
				"TestId":     uniqueId,
				"TestModule": "security",
				"Purpose":    "terratest",
				"Project":    "petclinic",
			},
		},
		NoColor:                true,
		RetryableTerraformErrors: map[string]string{
			"RequestError: send request failed": "Temporary AWS API error",
			"InvalidGroup.NotFound":             "Security group not found",
		},
		MaxRetries:         3,
		TimeBetweenRetries: 10 * time.Second,
	}

	// 테스트 종료 시 리소스 정리
	defer terraform.Destroy(t, terraformOptions)

	// Terraform 실행
	terraform.InitAndApply(t, terraformOptions)

	// 기본 출력값 검증
	t.Run("ValidateBasicOutputs", func(t *testing.T) {
		// ECS 보안 그룹 검증
		ecsSgId := terraform.Output(t, terraformOptions, "ecs_security_group_id")
		assert.NotEmpty(t, ecsSgId)
		assert.True(t, strings.HasPrefix(ecsSgId, "sg-"))

		// RDS 보안 그룹 검증
		rdsSgId := terraform.Output(t, terraformOptions, "rds_security_group_id")
		assert.NotEmpty(t, rdsSgId)
		assert.True(t, strings.HasPrefix(rdsSgId, "sg-"))

		// Aurora 보안 그룹 검증
		auroraSgId := terraform.Output(t, terraformOptions, "aurora_security_group_id")
		assert.NotEmpty(t, auroraSgId)
		assert.True(t, strings.HasPrefix(auroraSgId, "sg-"))
	})

	// 보안 그룹 규칙 검증
	t.Run("ValidateSecurityGroupRules", func(t *testing.T) {
		// ECS 보안 그룹 규칙
		ecsSgRules := terraform.OutputList(t, terraformOptions, "ecs_security_group_rules")
		assert.True(t, len(ecsSgRules) > 0, "ECS security group should have rules")

		// RDS 보안 그룹 규칙
		rdsSgRules := terraform.OutputList(t, terraformOptions, "rds_security_group_rules")
		assert.True(t, len(rdsSgRules) > 0, "RDS security group should have rules")

		// Aurora 보안 그룹 규칙
		auroraSgRules := terraform.OutputList(t, terraformOptions, "aurora_security_group_rules")
		assert.True(t, len(auroraSgRules) > 0, "Aurora security group should have rules")
	})

	// AWS API를 통한 실제 리소스 검증
	t.Run("ValidateAWSResources", func(t *testing.T) {
		validateSecurityGroupsInAWS(t, terraformOptions)
		validateSecurityGroupRules(t, terraformOptions)
	})

	// 네트워크 보안 검증
	t.Run("ValidateNetworkSecurity", func(t *testing.T) {
		validateNetworkSecurity(t, terraformOptions)
	})
}

// createTestVPCForSecurity - 테스트용 VPC 생성
func createTestVPCForSecurity(t *testing.T, uniqueId string) string {
	sess := session.Must(session.NewSession())
	ec2Client := ec2.New(sess)

	vpcName := fmt.Sprintf("test-vpc-security-%s", uniqueId)
	resp, err := ec2Client.CreateVpc(&ec2.CreateVpcInput{
		CidrBlock: aws.String("10.0.0.0/16"),
		TagSpecifications: []*ec2.TagSpecification{
			{
				ResourceType: aws.String("vpc"),
				Tags: []*ec2.Tag{
					{Key: aws.String("Name"), Value: aws.String(vpcName)},
					{Key: aws.String("TestId"), Value: aws.String(uniqueId)},
					{Key: aws.String("Purpose"), Value: aws.String("security-test")},
				},
			},
		},
	})
	require.NoError(t, err)

	// VPC가 사용 가능할 때까지 대기
	err = ec2Client.WaitUntilVpcAvailable(&ec2.DescribeVpcsInput{
		VpcIds: []*string{resp.Vpc.VpcId},
	})
	require.NoError(t, err)

	return *resp.Vpc.VpcId
}

// deleteTestVPCForSecurity - 테스트용 VPC 삭제
func deleteTestVPCForSecurity(t *testing.T, vpcId string) {
	sess := session.Must(session.NewSession())
	ec2Client := ec2.New(sess)

	_, err := ec2Client.DeleteVpc(&ec2.DeleteVpcInput{
		VpcId: aws.String(vpcId),
	})
	if err != nil {
		t.Logf("VPC 삭제 실패 (무시됨): %v", err)
	}
}

// validateSecurityGroupsInAWS - 보안 그룹 검증
func validateSecurityGroupsInAWS(t *testing.T, terraformOptions *terraform.Options) {
	sess := session.Must(session.NewSession())
	ec2Client := ec2.New(sess)

	// 모든 보안 그룹 ID 수집
	securityGroups := map[string]string{
		"ecs":    terraform.Output(t, terraformOptions, "ecs_security_group_id"),
		"rds":    terraform.Output(t, terraformOptions, "rds_security_group_id"),
		"aurora": terraform.Output(t, terraformOptions, "aurora_security_group_id"),
	}

	for sgType, sgId := range securityGroups {
		retry.DoWithRetry(t, fmt.Sprintf("Validate %s Security Group", sgType), 10, 5*time.Second, func() (string, error) {
			resp, err := ec2Client.DescribeSecurityGroups(&ec2.DescribeSecurityGroupsInput{
				GroupIds: []*string{aws.String(sgId)},
			})
			if err != nil {
				return "", err
			}

			require.Len(t, resp.SecurityGroups, 1)
			sg := resp.SecurityGroups[0]

			// 기본 속성 검증
			assert.NotEmpty(t, *sg.GroupName)
			assert.NotEmpty(t, *sg.Description)
			assert.Equal(t, terraform.Output(t, terraformOptions, "vpc_id"), *sg.VpcId)

			// 태그 검증
			found := false
			for _, tag := range sg.Tags {
				if *tag.Key == "TestModule" && *tag.Value == "security" {
					found = true
					break
				}
			}
			assert.True(t, found, fmt.Sprintf("%s 보안 그룹에서 TestModule 태그를 찾을 수 없습니다", sgType))

			return fmt.Sprintf("%s security group validation successful", sgType), nil
		})
	}
}

// validateSecurityGroupRules - 보안 그룹 규칙 검증
func validateSecurityGroupRules(t *testing.T, terraformOptions *terraform.Options) {
	sess := session.Must(session.NewSession())
	ec2Client := ec2.New(sess)

	// ECS 보안 그룹 규칙 검증
	ecsSgId := terraform.Output(t, terraformOptions, "ecs_security_group_id")
	validateECSSecurityGroupRules(t, ec2Client, ecsSgId)

	// RDS 보안 그룹 규칙 검증
	rdsSgId := terraform.Output(t, terraformOptions, "rds_security_group_id")
	validateRDSSecurityGroupRules(t, ec2Client, rdsSgId, ecsSgId)

	// Aurora 보안 그룹 규칙 검증
	auroraSgId := terraform.Output(t, terraformOptions, "aurora_security_group_id")
	validateAuroraSecurityGroupRules(t, ec2Client, auroraSgId, ecsSgId)
}

// validateECSSecurityGroupRules - ECS 보안 그룹 규칙 검증
func validateECSSecurityGroupRules(t *testing.T, ec2Client *ec2.EC2, ecsSgId string) {
	resp, err := ec2Client.DescribeSecurityGroups(&ec2.DescribeSecurityGroupsInput{
		GroupIds: []*string{aws.String(ecsSgId)},
	})
	require.NoError(t, err)
	require.Len(t, resp.SecurityGroups, 1)

	sg := resp.SecurityGroups[0]

	// 8080 포트 인바운드 규칙 확인
	port8080Found := false
	for _, rule := range sg.IpPermissions {
		if rule.FromPort != nil && rule.ToPort != nil &&
			*rule.FromPort == 8080 && *rule.ToPort == 8080 {
			port8080Found = true
			assert.Equal(t, "tcp", *rule.IpProtocol)
		}
	}
	assert.True(t, port8080Found, "ECS 보안 그룹에서 8080 포트 규칙을 찾을 수 없습니다")

	// 아웃바운드 규칙 확인 (모든 트래픽 허용)
	allOutboundFound := false
	for _, rule := range sg.IpPermissionsEgress {
		if *rule.IpProtocol == "-1" {
			allOutboundFound = true
		}
	}
	assert.True(t, allOutboundFound, "ECS 보안 그룹에서 아웃바운드 규칙을 찾을 수 없습니다")
}

// validateRDSSecurityGroupRules - RDS 보안 그룹 규칙 검증
func validateRDSSecurityGroupRules(t *testing.T, ec2Client *ec2.EC2, rdsSgId, ecsSgId string) {
	resp, err := ec2Client.DescribeSecurityGroups(&ec2.DescribeSecurityGroupsInput{
		GroupIds: []*string{aws.String(rdsSgId)},
	})
	require.NoError(t, err)
	require.Len(t, resp.SecurityGroups, 1)

	sg := resp.SecurityGroups[0]

	// ECS에서 RDS로의 3306 포트 인바운드 규칙 확인
	ecsToRdsFound := false
	for _, rule := range sg.IpPermissions {
		if rule.FromPort != nil && rule.ToPort != nil &&
			*rule.FromPort == 3306 && *rule.ToPort == 3306 {
			for _, group := range rule.UserIdGroupPairs {
				if *group.GroupId == ecsSgId {
					ecsToRdsFound = true
					break
				}
			}
		}
	}
	assert.True(t, ecsToRdsFound, "ECS에서 RDS(3306)로의 인바운드 규칙을 찾을 수 없습니다")
}

// validateAuroraSecurityGroupRules - Aurora 보안 그룹 규칙 검증
func validateAuroraSecurityGroupRules(t *testing.T, ec2Client *ec2.EC2, auroraSgId, ecsSgId string) {
	resp, err := ec2Client.DescribeSecurityGroups(&ec2.DescribeSecurityGroupsInput{
		GroupIds: []*string{aws.String(auroraSgId)},
	})
	require.NoError(t, err)
	require.Len(t, resp.SecurityGroups, 1)

	sg := resp.SecurityGroups[0]

	// ECS에서 Aurora로의 3306 포트 인바운드 규칙 확인
	ecsToAuroraFound := false
	for _, rule := range sg.IpPermissions {
		if rule.FromPort != nil && rule.ToPort != nil &&
			*rule.FromPort == 3306 && *rule.ToPort == 3306 {
			for _, group := range rule.UserIdGroupPairs {
				if *group.GroupId == ecsSgId {
					ecsToAuroraFound = true
					break
				}
			}
		}
	}
	assert.True(t, ecsToAuroraFound, "ECS에서 Aurora(3306)로의 인바운드 규칙을 찾을 수 없습니다")
}

// validateNetworkSecurity - 네트워크 보안 검증
func validateNetworkSecurity(t *testing.T, terraformOptions *terraform.Options) {
	// 보안 그룹 간의 관계 검증
	ecsSgId := terraform.Output(t, terraformOptions, "ecs_security_group_id")
	rdsSgId := terraform.Output(t, terraformOptions, "rds_security_group_id")
	auroraSgId := terraform.Output(t, terraformOptions, "aurora_security_group_id")

	// 모든 보안 그룹이 서로 다른지 확인
	securityGroups := []string{ecsSgId, rdsSgId, auroraSgId}
	for i, sg1 := range securityGroups {
		for j, sg2 := range securityGroups {
			if i != j {
				assert.NotEqual(t, sg1, sg2, "보안 그룹이 중복되어서는 안 됩니다")
			}
		}
	}

	// 최소 권한 원칙 검증 (기본적인 검증)
	assert.NotEmpty(t, ecsSgId, "ECS 보안 그룹이 생성되어야 합니다")
	assert.NotEmpty(t, rdsSgId, "RDS 보안 그룹이 생성되어야 합니다")
	assert.NotEmpty(t, auroraSgId, "Aurora 보안 그룹이 생성되어야 합니다")

	t.Log("네트워크 보안 기본 검증 완료")
}