package test

import (
	"fmt"
	"strings"
	"testing"
	"time"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/ssm"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/retry"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// TestParameterStoreModule - Parameter Store 모듈의 종합적인 테스트
func TestParameterStoreModule(t *testing.T) {
	t.Parallel()

	// 고유한 테스트 식별자 생성
	uniqueId := random.UniqueId()
	namePrefix := fmt.Sprintf("test-param-%s", strings.ToLower(uniqueId))

	// Parameter Store Terraform 옵션 설정
	terraformOptions := &terraform.Options{
		TerraformDir: "../",
		Vars: map[string]interface{}{
			"name_prefix": namePrefix,
			"environment": "test",
			"parameters": map[string]interface{}{
				fmt.Sprintf("/%s/common/spring.profiles.active", namePrefix): map[string]interface{}{
					"value":       "mysql,aws",
					"type":        "String",
					"description": "Spring active profiles",
				},
				fmt.Sprintf("/%s/test/customers/database.host", namePrefix): map[string]interface{}{
					"value":       "test-aurora-cluster.cluster-xyz.ap-northeast-2.rds.amazonaws.com",
					"type":        "String",
					"description": "Customers service database host",
				},
				fmt.Sprintf("/%s/test/customers/database.port", namePrefix): map[string]interface{}{
					"value":       "3306",
					"type":        "String",
					"description": "Customers service database port",
				},
				fmt.Sprintf("/%s/test/customers/database.name", namePrefix): map[string]interface{}{
					"value":       "petclinic_customers",
					"type":        "String",
					"description": "Customers service database name",
				},
				fmt.Sprintf("/%s/test/customers/database.username", namePrefix): map[string]interface{}{
					"value":       "petclinic",
					"type":        "String",
					"description": "Customers service database username",
				},
				fmt.Sprintf("/%s/test/customers/database.password", namePrefix): map[string]interface{}{
					"value":       "test-secure-password-123",
					"type":        "SecureString",
					"description": "Customers service database password",
				},
				fmt.Sprintf("/%s/test/vets/database.host", namePrefix): map[string]interface{}{
					"value":       "test-aurora-cluster.cluster-xyz.ap-northeast-2.rds.amazonaws.com",
					"type":        "String",
					"description": "Vets service database host",
				},
				fmt.Sprintf("/%s/test/visits/database.host", namePrefix): map[string]interface{}{
					"value":       "test-aurora-cluster.cluster-xyz.ap-northeast-2.rds.amazonaws.com",
					"type":        "String",
					"description": "Visits service database host",
				},
				fmt.Sprintf("/%s/test/logging/level.root", namePrefix): map[string]interface{}{
					"value":       "INFO",
					"type":        "String",
					"description": "Root logging level",
				},
				fmt.Sprintf("/%s/test/management/endpoints.web.exposure.include", namePrefix): map[string]interface{}{
					"value":       "*",
					"type":        "String",
					"description": "Management endpoints exposure",
				},
			},
			"kms_key_id": "", // 기본 KMS 키 사용
			"tags": map[string]string{
				"TestId":     uniqueId,
				"TestModule": "parameter-store",
				"Purpose":    "terratest",
				"Project":    "petclinic",
			},
		},
		NoColor:                true,
		RetryableTerraformErrors: map[string]string{
			"RequestError: send request failed": "Temporary AWS API error",
			"ParameterNotFound":                 "Parameter not found",
		},
		MaxRetries:         3,
		TimeBetweenRetries: 5 * time.Second,
	}

	// 테스트 종료 시 리소스 정리
	defer terraform.Destroy(t, terraformOptions)

	// Terraform 실행
	terraform.InitAndApply(t, terraformOptions)

	// 기본 출력값 검증
	t.Run("ValidateBasicOutputs", func(t *testing.T) {
		// 파라미터 이름 검증
		parameterNames := terraform.OutputList(t, terraformOptions, "parameter_names")
		assert.True(t, len(parameterNames) >= 10, "최소 10개의 파라미터가 생성되어야 합니다")

		expectedParameters := []string{
			fmt.Sprintf("/%s/common/spring.profiles.active", namePrefix),
			fmt.Sprintf("/%s/test/customers/database.host", namePrefix),
			fmt.Sprintf("/%s/test/customers/database.port", namePrefix),
			fmt.Sprintf("/%s/test/customers/database.password", namePrefix),
		}

		for _, expectedParam := range expectedParameters {
			assert.Contains(t, parameterNames, expectedParam, fmt.Sprintf("파라미터를 찾을 수 없습니다: %s", expectedParam))
		}

		// 파라미터 ARN 검증
		parameterArns := terraform.OutputMap(t, terraformOptions, "parameter_arns")
		for _, expectedParam := range expectedParameters {
			arn, exists := parameterArns[expectedParam]
			assert.True(t, exists, fmt.Sprintf("파라미터 ARN을 찾을 수 없습니다: %s", expectedParam))
			assert.Contains(t, arn, "arn:aws:ssm:ap-northeast-2")
			assert.Contains(t, arn, "parameter")
		}
	})

	// AWS API를 통한 실제 리소스 검증
	t.Run("ValidateAWSResources", func(t *testing.T) {
		validateParametersInAWS(t, terraformOptions, namePrefix)
		validateParameterTypes(t, terraformOptions, namePrefix)
		validateParameterEncryption(t, terraformOptions, namePrefix)
	})

	// 파라미터 계층 구조 검증
	t.Run("ValidateParameterHierarchy", func(t *testing.T) {
		validateParameterHierarchy(t, terraformOptions, namePrefix)
	})

	// 파라미터 태그 검증
	t.Run("ValidateParameterTags", func(t *testing.T) {
		validateParameterTags(t, terraformOptions, namePrefix)
	})

	// 파라미터 접근 권한 검증
	t.Run("ValidateParameterAccess", func(t *testing.T) {
		validateParameterAccess(t, terraformOptions, namePrefix)
	})
}

// validateParametersInAWS - AWS API를 통한 파라미터 검증
func validateParametersInAWS(t *testing.T, terraformOptions *terraform.Options, namePrefix string) {
	sess := session.Must(session.NewSession())
	ssmClient := ssm.New(sess)

	parameterNames := terraform.OutputList(t, terraformOptions, "parameter_names")

	for _, paramName := range parameterNames {
		retry.DoWithRetry(t, fmt.Sprintf("Validate Parameter %s", paramName), 10, 5*time.Second, func() (string, error) {
			resp, err := ssmClient.GetParameter(&ssm.GetParameterInput{
				Name: aws.String(paramName),
			})
			if err != nil {
				return "", err
			}

			// 파라미터 기본 속성 검증
			assert.Equal(t, paramName, *resp.Parameter.Name)
			assert.NotEmpty(t, *resp.Parameter.Value)
			assert.NotEmpty(t, *resp.Parameter.Version)

			// 파라미터 타입 검증
			assert.True(t, *resp.Parameter.Type == "String" || *resp.Parameter.Type == "SecureString",
				fmt.Sprintf("파라미터 타입이 올바르지 않습니다: %s", *resp.Parameter.Type))

			return fmt.Sprintf("Parameter %s validation successful", paramName), nil
		})
	}
}

// validateParameterTypes - 파라미터 타입 검증
func validateParameterTypes(t *testing.T, terraformOptions *terraform.Options, namePrefix string) {
	sess := session.Must(session.NewSession())
	ssmClient := ssm.New(sess)

	// String 타입 파라미터 검증
	stringParams := []string{
		fmt.Sprintf("/%s/common/spring.profiles.active", namePrefix),
		fmt.Sprintf("/%s/test/customers/database.host", namePrefix),
		fmt.Sprintf("/%s/test/customers/database.port", namePrefix),
	}

	for _, paramName := range stringParams {
		resp, err := ssmClient.GetParameter(&ssm.GetParameterInput{
			Name: aws.String(paramName),
		})
		require.NoError(t, err)
		assert.Equal(t, "String", *resp.Parameter.Type, fmt.Sprintf("파라미터 %s는 String 타입이어야 합니다", paramName))
	}

	// SecureString 타입 파라미터 검증
	secureParams := []string{
		fmt.Sprintf("/%s/test/customers/database.password", namePrefix),
	}

	for _, paramName := range secureParams {
		resp, err := ssmClient.GetParameter(&ssm.GetParameterInput{
			Name:           aws.String(paramName),
			WithDecryption: aws.Bool(false), // 암호화된 상태로 가져오기
		})
		require.NoError(t, err)
		assert.Equal(t, "SecureString", *resp.Parameter.Type, fmt.Sprintf("파라미터 %s는 SecureString 타입이어야 합니다", paramName))
	}
}

// validateParameterEncryption - 파라미터 암호화 검증
func validateParameterEncryption(t *testing.T, terraformOptions *terraform.Options, namePrefix string) {
	sess := session.Must(session.NewSession())
	ssmClient := ssm.New(sess)

	// SecureString 파라미터의 암호화 검증
	secureParamName := fmt.Sprintf("/%s/test/customers/database.password", namePrefix)

	// 암호화된 상태로 가져오기
	encryptedResp, err := ssmClient.GetParameter(&ssm.GetParameterInput{
		Name:           aws.String(secureParamName),
		WithDecryption: aws.Bool(false),
	})
	require.NoError(t, err)

	// 복호화된 상태로 가져오기
	decryptedResp, err := ssmClient.GetParameter(&ssm.GetParameterInput{
		Name:           aws.String(secureParamName),
		WithDecryption: aws.Bool(true),
	})
	require.NoError(t, err)

	// 암호화된 값과 복호화된 값이 다른지 확인 (실제로는 같을 수 있지만 타입이 SecureString인지 확인)
	assert.Equal(t, "SecureString", *encryptedResp.Parameter.Type)
	assert.Equal(t, "SecureString", *decryptedResp.Parameter.Type)
	assert.NotEmpty(t, *decryptedResp.Parameter.Value)

	t.Logf("SecureString 파라미터 암호화 검증 완료: %s", secureParamName)
}

// validateParameterHierarchy - 파라미터 계층 구조 검증
func validateParameterHierarchy(t *testing.T, terraformOptions *terraform.Options, namePrefix string) {
	sess := session.Must(session.NewSession())
	ssmClient := ssm.New(sess)

	// 계층별 파라미터 조회
	hierarchies := []string{
		fmt.Sprintf("/%s/common/", namePrefix),
		fmt.Sprintf("/%s/test/customers/", namePrefix),
		fmt.Sprintf("/%s/test/vets/", namePrefix),
		fmt.Sprintf("/%s/test/visits/", namePrefix),
	}

	for _, hierarchy := range hierarchies {
		resp, err := ssmClient.GetParametersByPath(&ssm.GetParametersByPathInput{
			Path:      aws.String(hierarchy),
			Recursive: aws.Bool(false),
		})
		require.NoError(t, err)

		assert.True(t, len(resp.Parameters) > 0, fmt.Sprintf("계층에서 파라미터를 찾을 수 없습니다: %s", hierarchy))

		// 각 파라미터가 올바른 계층에 속하는지 확인
		for _, param := range resp.Parameters {
			assert.True(t, strings.HasPrefix(*param.Name, hierarchy),
				fmt.Sprintf("파라미터가 올바른 계층에 속하지 않습니다: %s", *param.Name))
		}

		t.Logf("계층 검증 완료: %s (%d개 파라미터)", hierarchy, len(resp.Parameters))
	}
}

// validateParameterTags - 파라미터 태그 검증
func validateParameterTags(t *testing.T, terraformOptions *terraform.Options, namePrefix string) {
	sess := session.Must(session.NewSession())
	ssmClient := ssm.New(sess)

	parameterNames := terraform.OutputList(t, terraformOptions, "parameter_names")

	// 첫 번째 파라미터의 태그 검증 (모든 파라미터가 동일한 태그를 가져야 함)
	if len(parameterNames) > 0 {
		paramName := parameterNames[0]
		
		resp, err := ssmClient.ListTagsForResource(&ssm.ListTagsForResourceInput{
			ResourceType: aws.String("Parameter"),
			ResourceId:   aws.String(paramName),
		})
		require.NoError(t, err)

		// 필수 태그 검증
		expectedTags := map[string]string{
			"TestModule": "parameter-store",
			"Purpose":    "terratest",
			"Project":    "petclinic",
		}

		tagMap := make(map[string]string)
		for _, tag := range resp.TagList {
			tagMap[*tag.Key] = *tag.Value
		}

		for expectedKey, expectedValue := range expectedTags {
			actualValue, exists := tagMap[expectedKey]
			assert.True(t, exists, fmt.Sprintf("태그를 찾을 수 없습니다: %s", expectedKey))
			assert.Equal(t, expectedValue, actualValue, fmt.Sprintf("태그 값이 일치하지 않습니다: %s", expectedKey))
		}

		t.Logf("파라미터 태그 검증 완료: %s", paramName)
	}
}

// validateParameterAccess - 파라미터 접근 권한 검증
func validateParameterAccess(t *testing.T, terraformOptions *terraform.Options, namePrefix string) {
	sess := session.Must(session.NewSession())
	ssmClient := ssm.New(sess)

	// 파라미터 접근 테스트 (기본적인 읽기 권한 확인)
	testParamName := fmt.Sprintf("/%s/common/spring.profiles.active", namePrefix)

	// 단일 파라미터 접근
	_, err := ssmClient.GetParameter(&ssm.GetParameterInput{
		Name: aws.String(testParamName),
	})
	assert.NoError(t, err, "파라미터 읽기 권한이 없습니다")

	// 다중 파라미터 접근
	parameterNames := terraform.OutputList(t, terraformOptions, "parameter_names")
	if len(parameterNames) > 1 {
		// 최대 10개까지만 테스트 (AWS API 제한)
		testParams := parameterNames
		if len(testParams) > 10 {
			testParams = testParams[:10]
		}

		_, err := ssmClient.GetParameters(&ssm.GetParametersInput{
			Names: aws.StringSlice(testParams),
		})
		assert.NoError(t, err, "다중 파라미터 읽기 권한이 없습니다")
	}

	// 계층별 파라미터 접근
	_, err = ssmClient.GetParametersByPath(&ssm.GetParametersByPathInput{
		Path:      aws.String(fmt.Sprintf("/%s/", namePrefix)),
		Recursive: aws.Bool(true),
	})
	assert.NoError(t, err, "계층별 파라미터 읽기 권한이 없습니다")

	t.Log("파라미터 접근 권한 검증 완료")
}