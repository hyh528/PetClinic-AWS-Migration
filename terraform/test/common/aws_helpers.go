package common

import (
	"context"
	"fmt"
	"testing"
	"time"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/ec2"
	"github.com/aws/aws-sdk-go/service/ecs"
	"github.com/aws/aws-sdk-go/service/elbv2"
	"github.com/aws/aws-sdk-go/service/rds"
	"github.com/gruntwork-io/terratest/modules/terraform"
)

// AWSHelper AWS 리소스 검증을 위한 헬퍼 구조체
type AWSHelper struct {
	session *session.Session
	region  string
}

// NewAWSHelper AWS 헬퍼를 생성합니다
func NewAWSHelper(region string) (*AWSHelper, error) {
	sess, err := session.NewSession(&aws.Config{
		Region: aws.String(region),
	})
	if err != nil {
		return nil, fmt.Errorf("failed to create AWS session: %w", err)
	}

	return &AWSHelper{
		session: sess,
		region:  region,
	}, nil
}

// ValidateVPCResources VPC 관련 리소스를 검증합니다
func (h *AWSHelper) ValidateVPCResources(t *testing.T, terraformOptions *terraform.Options) {
	ec2Client := ec2.New(h.session)

	// VPC 검증
	vpcID := terraform.Output(t, terraformOptions, "vpc_id")
	vpc, err := h.getVPCByID(ec2Client, vpcID)
	if err != nil {
		t.Fatalf("Failed to get VPC %s: %v", vpcID, err)
	}

	t.Logf("✓ VPC %s found with CIDR: %s", vpcID, *vpc.CidrBlock)

	// 서브넷 검증
	h.validateSubnets(t, ec2Client, terraformOptions)

	// 인터넷 게이트웨이 검증
	h.validateInternetGateway(t, ec2Client, terraformOptions, vpcID)

	// NAT 게이트웨이 검증
	h.validateNATGateways(t, ec2Client, terraformOptions)

	// 라우팅 테이블 검증
	h.validateRouteTables(t, ec2Client, terraformOptions, vpcID)
}

// ValidateECSResources ECS 관련 리소스를 검증합니다
func (h *AWSHelper) ValidateECSResources(t *testing.T, terraformOptions *terraform.Options) {
	ecsClient := ecs.New(h.session)

	// 클러스터 검증
	clusterName := terraform.Output(t, terraformOptions, "ecs_cluster_name")
	cluster, err := h.getECSCluster(ecsClient, clusterName)
	if err != nil {
		t.Fatalf("Failed to get ECS cluster %s: %v", clusterName, err)
	}

	if *cluster.Status != "ACTIVE" {
		t.Fatalf("ECS cluster %s is not active, status: %s", clusterName, *cluster.Status)
	}

	t.Logf("✓ ECS cluster %s is active with %d running tasks", clusterName, *cluster.RunningTasksCount)

	// 서비스 검증 (있는 경우)
	if serviceName := terraform.OutputRequired(t, terraformOptions, "ecs_service_name"); serviceName != "" {
		h.validateECSService(t, ecsClient, clusterName, serviceName)
	}
}

// ValidateRDSResources RDS/Aurora 관련 리소스를 검증합니다
func (h *AWSHelper) ValidateRDSResources(t *testing.T, terraformOptions *terraform.Options) {
	rdsClient := rds.New(h.session)

	// Aurora 클러스터 검증
	clusterID := terraform.Output(t, terraformOptions, "cluster_identifier")
	cluster, err := h.getRDSCluster(rdsClient, clusterID)
	if err != nil {
		t.Fatalf("Failed to get RDS cluster %s: %v", clusterID, err)
	}

	if *cluster.Status != "available" {
		t.Fatalf("RDS cluster %s is not available, status: %s", clusterID, *cluster.Status)
	}

	t.Logf("✓ RDS cluster %s is available with engine: %s", clusterID, *cluster.Engine)

	// 클러스터 인스턴스 검증
	h.validateRDSClusterInstances(t, rdsClient, clusterID)
}

// ValidateALBResources ALB 관련 리소스를 검증합니다
func (h *AWSHelper) ValidateALBResources(t *testing.T, terraformOptions *terraform.Options) {
	elbClient := elbv2.New(h.session)

	// ALB 검증
	albArn := terraform.Output(t, terraformOptions, "alb_arn")
	alb, err := h.getALB(elbClient, albArn)
	if err != nil {
		t.Fatalf("Failed to get ALB %s: %v", albArn, err)
	}

	if *alb.State.Code != "active" {
		t.Fatalf("ALB %s is not active, state: %s", albArn, *alb.State.Code)
	}

	t.Logf("✓ ALB %s is active with DNS: %s", *alb.LoadBalancerName, *alb.DNSName)

	// 타겟 그룹 검증
	h.validateTargetGroups(t, elbClient, terraformOptions)
}

// WaitForECSServiceStable ECS 서비스가 안정화될 때까지 대기합니다
func (h *AWSHelper) WaitForECSServiceStable(t *testing.T, clusterName, serviceName string, timeout time.Duration) {
	ecsClient := ecs.New(h.session)

	t.Logf("Waiting for ECS service %s to be stable (max %v)", serviceName, timeout)

	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()

	ticker := time.NewTicker(30 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			t.Fatalf("Timeout waiting for ECS service %s to be stable", serviceName)
		case <-ticker.C:
			service, err := h.getECSService(ecsClient, clusterName, serviceName)
			if err != nil {
				t.Logf("Error checking service status: %v", err)
				continue
			}

			if *service.RunningCount == *service.DesiredCount && len(service.Deployments) == 1 {
				deployment := service.Deployments[0]
				if *deployment.Status == "PRIMARY" && *deployment.RolloutState == "COMPLETED" {
					t.Logf("✓ ECS service %s is stable", serviceName)
					return
				}
			}

			t.Logf("ECS service %s not yet stable: running=%d, desired=%d",
				serviceName, *service.RunningCount, *service.DesiredCount)
		}
	}
}

// 내부 헬퍼 메서드들

func (h *AWSHelper) getVPCByID(client *ec2.EC2, vpcID string) (*ec2.Vpc, error) {
	result, err := client.DescribeVpcs(&ec2.DescribeVpcsInput{
		VpcIds: []*string{aws.String(vpcID)},
	})
	if err != nil {
		return nil, err
	}

	if len(result.Vpcs) == 0 {
		return nil, fmt.Errorf("VPC %s not found", vpcID)
	}

	return result.Vpcs[0], nil
}

func (h *AWSHelper) validateSubnets(t *testing.T, client *ec2.EC2, terraformOptions *terraform.Options) {
	// 퍼블릭 서브넷 검증
	if publicSubnets := terraform.OutputList(t, terraformOptions, "public_subnet_ids"); len(publicSubnets) > 0 {
		for _, subnetID := range publicSubnets {
			subnet, err := h.getSubnetByID(client, subnetID)
			if err != nil {
				t.Errorf("Failed to get public subnet %s: %v", subnetID, err)
				continue
			}
			t.Logf("✓ Public subnet %s found in AZ: %s", subnetID, *subnet.AvailabilityZone)
		}
	}

	// 프라이빗 서브넷 검증
	if privateSubnets := terraform.OutputList(t, terraformOptions, "private_app_subnet_ids"); len(privateSubnets) > 0 {
		for _, subnetID := range privateSubnets {
			subnet, err := h.getSubnetByID(client, subnetID)
			if err != nil {
				t.Errorf("Failed to get private subnet %s: %v", subnetID, err)
				continue
			}
			t.Logf("✓ Private subnet %s found in AZ: %s", subnetID, *subnet.AvailabilityZone)
		}
	}
}

func (h *AWSHelper) getSubnetByID(client *ec2.EC2, subnetID string) (*ec2.Subnet, error) {
	result, err := client.DescribeSubnets(&ec2.DescribeSubnetsInput{
		SubnetIds: []*string{aws.String(subnetID)},
	})
	if err != nil {
		return nil, err
	}

	if len(result.Subnets) == 0 {
		return nil, fmt.Errorf("subnet %s not found", subnetID)
	}

	return result.Subnets[0], nil
}

func (h *AWSHelper) validateInternetGateway(t *testing.T, client *ec2.EC2, terraformOptions *terraform.Options, vpcID string) {
	igwID := terraform.Output(t, terraformOptions, "internet_gateway_id")
	if igwID == "" {
		return // IGW가 없는 경우 건너뛰기
	}

	result, err := client.DescribeInternetGateways(&ec2.DescribeInternetGatewaysInput{
		InternetGatewayIds: []*string{aws.String(igwID)},
	})
	if err != nil {
		t.Errorf("Failed to get internet gateway %s: %v", igwID, err)
		return
	}

	if len(result.InternetGateways) == 0 {
		t.Errorf("Internet gateway %s not found", igwID)
		return
	}

	igw := result.InternetGateways[0]
	
	// VPC 연결 확인
	attached := false
	for _, attachment := range igw.Attachments {
		if *attachment.VpcId == vpcID && *attachment.State == "available" {
			attached = true
			break
		}
	}

	if !attached {
		t.Errorf("Internet gateway %s is not properly attached to VPC %s", igwID, vpcID)
		return
	}

	t.Logf("✓ Internet gateway %s is properly attached to VPC", igwID)
}

func (h *AWSHelper) validateNATGateways(t *testing.T, client *ec2.EC2, terraformOptions *terraform.Options) {
	natGatewayIDs := terraform.OutputList(t, terraformOptions, "nat_gateway_ids")
	if len(natGatewayIDs) == 0 {
		return // NAT Gateway가 없는 경우 건너뛰기
	}

	for _, natID := range natGatewayIDs {
		result, err := client.DescribeNatGateways(&ec2.DescribeNatGatewaysInput{
			NatGatewayIds: []*string{aws.String(natID)},
		})
		if err != nil {
			t.Errorf("Failed to get NAT gateway %s: %v", natID, err)
			continue
		}

		if len(result.NatGateways) == 0 {
			t.Errorf("NAT gateway %s not found", natID)
			continue
		}

		natGateway := result.NatGateways[0]
		if *natGateway.State != "available" {
			t.Errorf("NAT gateway %s is not available, state: %s", natID, *natGateway.State)
			continue
		}

		t.Logf("✓ NAT gateway %s is available in subnet: %s", natID, *natGateway.SubnetId)
	}
}

func (h *AWSHelper) validateRouteTables(t *testing.T, client *ec2.EC2, terraformOptions *terraform.Options, vpcID string) {
	// 라우팅 테이블 검증 로직
	result, err := client.DescribeRouteTables(&ec2.DescribeRouteTablesInput{
		Filters: []*ec2.Filter{
			{
				Name:   aws.String("vpc-id"),
				Values: []*string{aws.String(vpcID)},
			},
		},
	})
	if err != nil {
		t.Errorf("Failed to get route tables for VPC %s: %v", vpcID, err)
		return
	}

	t.Logf("✓ Found %d route tables for VPC %s", len(result.RouteTables), vpcID)
}

func (h *AWSHelper) getECSCluster(client *ecs.ECS, clusterName string) (*ecs.Cluster, error) {
	result, err := client.DescribeClusters(&ecs.DescribeClustersInput{
		Clusters: []*string{aws.String(clusterName)},
	})
	if err != nil {
		return nil, err
	}

	if len(result.Clusters) == 0 {
		return nil, fmt.Errorf("ECS cluster %s not found", clusterName)
	}

	return result.Clusters[0], nil
}

func (h *AWSHelper) getECSService(client *ecs.ECS, clusterName, serviceName string) (*ecs.Service, error) {
	result, err := client.DescribeServices(&ecs.DescribeServicesInput{
		Cluster:  aws.String(clusterName),
		Services: []*string{aws.String(serviceName)},
	})
	if err != nil {
		return nil, err
	}

	if len(result.Services) == 0 {
		return nil, fmt.Errorf("ECS service %s not found in cluster %s", serviceName, clusterName)
	}

	return result.Services[0], nil
}

func (h *AWSHelper) validateECSService(t *testing.T, client *ecs.ECS, clusterName, serviceName string) {
	service, err := h.getECSService(client, clusterName, serviceName)
	if err != nil {
		t.Errorf("Failed to get ECS service %s: %v", serviceName, err)
		return
	}

	if *service.Status != "ACTIVE" {
		t.Errorf("ECS service %s is not active, status: %s", serviceName, *service.Status)
		return
	}

	t.Logf("✓ ECS service %s is active with %d/%d tasks running",
		serviceName, *service.RunningCount, *service.DesiredCount)
}

func (h *AWSHelper) getRDSCluster(client *rds.RDS, clusterID string) (*rds.DBCluster, error) {
	result, err := client.DescribeDBClusters(&rds.DescribeDBClustersInput{
		DBClusterIdentifier: aws.String(clusterID),
	})
	if err != nil {
		return nil, err
	}

	if len(result.DBClusters) == 0 {
		return nil, fmt.Errorf("RDS cluster %s not found", clusterID)
	}

	return result.DBClusters[0], nil
}

func (h *AWSHelper) validateRDSClusterInstances(t *testing.T, client *rds.RDS, clusterID string) {
	result, err := client.DescribeDBClusterMembers(&rds.DescribeDBClusterMembersInput{
		DBClusterIdentifier: aws.String(clusterID),
	})
	if err != nil {
		t.Errorf("Failed to get cluster members for %s: %v", clusterID, err)
		return
	}

	writerCount := 0
	readerCount := 0

	for _, member := range result.DBClusterMembers {
		if *member.IsClusterWriter {
			writerCount++
		} else {
			readerCount++
		}
	}

	t.Logf("✓ RDS cluster %s has %d writer(s) and %d reader(s)", clusterID, writerCount, readerCount)

	if writerCount == 0 {
		t.Errorf("RDS cluster %s has no writer instances", clusterID)
	}
}

func (h *AWSHelper) getALB(client *elbv2.ELBV2, albArn string) (*elbv2.LoadBalancer, error) {
	result, err := client.DescribeLoadBalancers(&elbv2.DescribeLoadBalancersInput{
		LoadBalancerArns: []*string{aws.String(albArn)},
	})
	if err != nil {
		return nil, err
	}

	if len(result.LoadBalancers) == 0 {
		return nil, fmt.Errorf("ALB %s not found", albArn)
	}

	return result.LoadBalancers[0], nil
}

func (h *AWSHelper) validateTargetGroups(t *testing.T, client *elbv2.ELBV2, terraformOptions *terraform.Options) {
	// 타겟 그룹 검증 로직 (출력값이 있는 경우)
	if targetGroupArns := terraform.OutputList(t, terraformOptions, "target_group_arns"); len(targetGroupArns) > 0 {
		for _, tgArn := range targetGroupArns {
			result, err := client.DescribeTargetGroups(&elbv2.DescribeTargetGroupsInput{
				TargetGroupArns: []*string{aws.String(tgArn)},
			})
			if err != nil {
				t.Errorf("Failed to get target group %s: %v", tgArn, err)
				continue
			}

			if len(result.TargetGroups) == 0 {
				t.Errorf("Target group %s not found", tgArn)
				continue
			}

			tg := result.TargetGroups[0]
			t.Logf("✓ Target group %s found with protocol: %s", *tg.TargetGroupName, *tg.Protocol)
		}
	}
}