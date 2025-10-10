package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestDatabaseModule(t *testing.T) {
	t.Parallel()

	terraformOptions := &terraform.Options{
		TerraformDir: "../",

		Vars: map[string]interface{}{
			"name_prefix":             "test-petclinic",
			"private_db_subnet_ids":   []string{"subnet-12345", "subnet-67890"}, // 실제 서브넷 ID로 교체 필요
			"vpc_security_group_ids":  []string{"sg-12345"},
			"engine_version":          "8.0",
			"instance_class":          "db.t3.micro",
			"db_name":                 "petclinic_test",
			"db_username":             "admin",
			"db_port":                 3306,
			"backup_retention_period": 7,
			"tags": map[string]string{
				"Project":     "petclinic",
				"Environment": "test",
			},
		},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// 클러스터 식별자 검증
	clusterId := terraform.Output(t, terraformOptions, "cluster_identifier")
	assert.Contains(t, clusterId, "test-petclinic", "Cluster ID should contain name prefix")

	// 엔진 검증
	engine := terraform.Output(t, terraformOptions, "engine")
	assert.Equal(t, "aurora-mysql", engine, "Engine should be aurora-mysql")

	// 엔드포인트 검증
	endpoint := terraform.Output(t, terraformOptions, "endpoint")
	assert.NotEmpty(t, endpoint, "Endpoint should not be empty")

	readerEndpoint := terraform.Output(t, terraformOptions, "reader_endpoint")
	assert.NotEmpty(t, readerEndpoint, "Reader endpoint should not be empty")

	// 포트 검증
	port := terraform.Output(t, terraformOptions, "port")
	assert.Equal(t, "3306", port, "Port should be 3306")

	// 데이터베이스 이름 검증
	dbName := terraform.Output(t, terraformOptions, "database_name")
	assert.Equal(t, "petclinic_test", dbName, "Database name should match input")

	// 인스턴스 검증
	clusterInstances := terraform.OutputList(t, terraformOptions, "cluster_instances")
	assert.Len(t, clusterInstances, 2, "Should have 2 cluster instances (writer and reader)")
}
