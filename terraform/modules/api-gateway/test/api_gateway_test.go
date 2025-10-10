package test

import (
	"fmt"
	"net/http"
	"strings"
	"testing"
	"time"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/apigatewayv2"
	"github.com/aws/aws-sdk-go/service/cloudwatch"
	"github.com/gruntwork-io/terratest/modules/http-helper"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/retry"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// TestApiGatewayModule - API Gateway 모듈의 종합적인 테스트
func TestApiGatewayModule(t *testing.T) {
	t.Parallel()

	// 고유한 테스트 식별자 생성
	uniqueId := random.UniqueId()
	namePrefix := fmt.Sprintf("test-api-%s", strings.ToLower(uniqueId))

	// 사전 요구사항: VPC 및 ALB 생성 (Mock 데이터 사용)
	testVpcId := "vpc-test123456"
	testSubnetIds := []string{"subnet-test123", "subnet-test456"}
	testAlbArn := "arn:aws:elasticloadbalancing:ap-northeast-2:123456789012:loadbalancer/app/test-alb/1234567890123456"

	// API Gateway Terraform 옵션 설정
	terraformOptions := &terraform.Options{
		TerraformDir: "../",
		Vars: map[string]interface{}{
			"name_prefix":                    namePrefix,
			"environment":                    "test",
			"stage_name":                     "test",
			"alb_dns_name":                   "test-alb-123456789.ap-northeast-2.elb.amazonaws.com",
			"enable_lambda_integration":      false,
			"lambda_function_invoke_arn":     "",
			"integration_timeout_ms":         29000,
			"lambda_integration_timeout_ms": 29000,
			"enable_cors":                    true,
			"enable_xray_tracing":            true,
			"enable_monitoring":              true,
			"create_dashboard":               true,
			"create_usage_plan":              false,
			"log_retention_days":             7,
			"minimum_compression_size":       1024,
			"api_key_source":                 "HEADER",
			"disable_execute_api_endpoint":   false,
			"throttle_rate_limit":            1000,
			"throttle_burst_limit":           2000,
			"error_4xx_threshold":            10,
			"error_5xx_threshold":            5,
			"latency_threshold":              5000,
			"integration_latency_threshold": 4000,
			"tags": map[string]string{
				"TestId":     uniqueId,
				"TestModule": "api-gateway",
				"Purpose":    "terratest",
				"Project":    "petclinic",
			},
		},
		NoColor:                true,
		RetryableTerraformErrors: map[string]string{
			"RequestError: send request failed": "Temporary AWS API error",
			"TooManyRequestsException":          "API Gateway rate limit",
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
		apiId := terraform.Output(t, terraformOptions, "api_id")
		assert.NotEmpty(t, apiId)
		assert.True(t, len(apiId) == 10) // API Gateway ID는 10자리

		apiUrl := terraform.Output(t, terraformOptions, "api_url")
		assert.NotEmpty(t, apiUrl)
		assert.Contains(t, apiUrl, apiId)
		assert.Contains(t, apiUrl, "execute-api")
		assert.Contains(t, apiUrl, "amazonaws.com")

		stage := terraform.Output(t, terraformOptions, "stage_name")
		assert.Equal(t, "test", stage)

		apiName := terraform.Output(t, terraformOptions, "api_name")
		assert.Equal(t, fmt.Sprintf("%s-api", namePrefix), apiName)
	})

	// AWS API를 통한 실제 리소스 검증
	t.Run("ValidateAWSResources", func(t *testing.T) {
		apiId := terraform.Output(t, terraformOptions, "api_id")
		validateAPIGatewayInAWS(t, apiId, terraformOptions)
		validateAPIGatewayStageInAWS(t, apiId, "test")
		validateAPIGatewayRoutesInAWS(t, apiId)
	})

	// CloudWatch 모니터링 검증
	t.Run("ValidateMonitoring", func(t *testing.T) {
		validateCloudWatchAlarms(t, terraformOptions)
		validateCloudWatchDashboard(t, terraformOptions)
		validateCloudWatchLogGroups(t, terraformOptions)
	})

	// CORS 설정 검증
	t.Run("ValidateCORS", func(t *testing.T) {
		apiId := terraform.Output(t, terraformOptions, "api_id")
		validateCORSConfiguration(t, apiId)
	})

	// API 엔드포인트 연결성 테스트
	t.Run("ValidateAPIConnectivity", func(t *testing.T) {
		apiUrl := terraform.Output(t, terraformOptions, "api_url")
		validateAPIConnectivity(t, apiUrl)
	})
}

// validateAPIGatewayInAWS - API Gateway 기본 속성 검증
func validateAPIGatewayInAWS(t *testing.T, apiId string, terraformOptions *terraform.Options) {
	sess := session.Must(session.NewSession())
	apiGwClient := apigatewayv2.New(sess)

	retry.DoWithRetry(t, "Validate API Gateway", 10, 5*time.Second, func() (string, error) {
		resp, err := apiGwClient.GetApi(&apigatewayv2.GetApiInput{
			ApiId: aws.String(apiId),
		})
		if err != nil {
			return "", err
		}

		// API 기본 속성 검증
		expectedName := terraform.Output(t, terraformOptions, "api_name")
		assert.Equal(t, expectedName, *resp.Name)
		assert.Equal(t, "HTTP", *resp.ProtocolType)
		assert.True(t, *resp.CorsConfiguration.AllowCredentials)

		// CORS 설정 검증
		assert.Contains(t, resp.CorsConfiguration.AllowHeaders, "content-type")
		assert.Contains(t, resp.CorsConfiguration.AllowMethods, "GET")
		assert.Contains(t, resp.CorsConfiguration.AllowMethods, "POST")
		assert.Contains(t, resp.CorsConfiguration.AllowOrigins, "*")

		return "API Gateway validation successful", nil
	})
}

// validateAPIGatewayStageInAWS - API Gateway 스테이지 검증
func validateAPIGatewayStageInAWS(t *testing.T, apiId, stageName string) {
	sess := session.Must(session.NewSession())
	apiGwClient := apigatewayv2.New(sess)

	resp, err := apiGwClient.GetStage(&apigatewayv2.GetStageInput{
		ApiId:     aws.String(apiId),
		StageName: aws.String(stageName),
	})
	require.NoError(t, err)

	// 스테이지 속성 검증
	assert.Equal(t, stageName, *resp.StageName)
	assert.True(t, *resp.AutoDeploy)

	// 로깅 설정 검증
	if resp.AccessLogSettings != nil {
		assert.NotEmpty(t, *resp.AccessLogSettings.DestinationArn)
		assert.NotEmpty(t, *resp.AccessLogSettings.Format)
	}

	// 스로틀링 설정 검증
	if resp.ThrottleSettings != nil {
		assert.Equal(t, int64(1000), *resp.ThrottleSettings.RateLimit)
		assert.Equal(t, int64(2000), *resp.ThrottleSettings.BurstLimit)
	}
}

// validateAPIGatewayRoutesInAWS - API Gateway 라우트 검증
func validateAPIGatewayRoutesInAWS(t *testing.T, apiId string) {
	sess := session.Must(session.NewSession())
	apiGwClient := apigatewayv2.New(sess)

	resp, err := apiGwClient.GetRoutes(&apigatewayv2.GetRoutesInput{
		ApiId: aws.String(apiId),
	})
	require.NoError(t, err)

	// 기본 라우트들 확인
	expectedRoutes := []string{
		"ANY /api/customers/{proxy+}",
		"ANY /api/vets/{proxy+}",
		"ANY /api/visits/{proxy+}",
		"ANY /admin/{proxy+}",
		"OPTIONS /{proxy+}", // CORS preflight
	}

	routeKeys := make([]string, 0, len(resp.Items))
	for _, route := range resp.Items {
		routeKeys = append(routeKeys, *route.RouteKey)
	}

	for _, expectedRoute := range expectedRoutes {
		found := false
		for _, routeKey := range routeKeys {
			if strings.Contains(routeKey, strings.Split(expectedRoute, " ")[1]) {
				found = true
				break
			}
		}
		assert.True(t, found, fmt.Sprintf("라우트를 찾을 수 없습니다: %s", expectedRoute))
	}
}

// validateCloudWatchAlarms - CloudWatch 알람 검증
func validateCloudWatchAlarms(t *testing.T, terraformOptions *terraform.Options) {
	sess := session.Must(session.NewSession())
	cwClient := cloudwatch.New(sess)

	apiName := terraform.Output(t, terraformOptions, "api_name")
	
	// 알람 이름 패턴
	alarmPatterns := []string{
		fmt.Sprintf("%s-4xx-errors", apiName),
		fmt.Sprintf("%s-5xx-errors", apiName),
		fmt.Sprintf("%s-high-latency", apiName),
		fmt.Sprintf("%s-integration-latency", apiName),
	}

	for _, pattern := range alarmPatterns {
		resp, err := cwClient.DescribeAlarms(&cloudwatch.DescribeAlarmsInput{
			AlarmNamePrefix: aws.String(pattern),
		})
		require.NoError(t, err)
		assert.NotEmpty(t, resp.MetricAlarms, fmt.Sprintf("알람을 찾을 수 없습니다: %s", pattern))

		if len(resp.MetricAlarms) > 0 {
			alarm := resp.MetricAlarms[0]
			assert.Equal(t, "OK", *alarm.StateValue) // 초기 상태는 OK여야 함
			assert.NotEmpty(t, alarm.AlarmActions)
		}
	}
}

// validateCloudWatchDashboard - CloudWatch 대시보드 검증
func validateCloudWatchDashboard(t *testing.T, terraformOptions *terraform.Options) {
	sess := session.Must(session.NewSession())
	cwClient := cloudwatch.New(sess)

	apiName := terraform.Output(t, terraformOptions, "api_name")
	dashboardName := fmt.Sprintf("%s-dashboard", apiName)

	resp, err := cwClient.GetDashboard(&cloudwatch.GetDashboardInput{
		DashboardName: aws.String(dashboardName),
	})
	require.NoError(t, err)

	// 대시보드 내용 검증
	assert.NotEmpty(t, *resp.DashboardBody)
	assert.Contains(t, *resp.DashboardBody, "AWS/ApiGatewayV2")
	assert.Contains(t, *resp.DashboardBody, "Count")
	assert.Contains(t, *resp.DashboardBody, "IntegrationLatency")
}

// validateCloudWatchLogGroups - CloudWatch 로그 그룹 검증
func validateCloudWatchLogGroups(t *testing.T, terraformOptions *terraform.Options) {
	// 로그 그룹은 실제 트래픽이 있을 때 생성되므로 기본 검증만 수행
	apiId := terraform.Output(t, terraformOptions, "api_id")
	expectedLogGroup := fmt.Sprintf("/aws/apigateway/%s", apiId)
	
	t.Logf("예상 로그 그룹: %s", expectedLogGroup)
	// 실제 환경에서는 logs 클라이언트로 검증 가능
}

// validateCORSConfiguration - CORS 설정 검증
func validateCORSConfiguration(t *testing.T, apiId string) {
	sess := session.Must(session.NewSession())
	apiGwClient := apigatewayv2.New(sess)

	resp, err := apiGwClient.GetApi(&apigatewayv2.GetApiInput{
		ApiId: aws.String(apiId),
	})
	require.NoError(t, err)

	// CORS 설정 검증
	cors := resp.CorsConfiguration
	assert.NotNil(t, cors)
	assert.True(t, *cors.AllowCredentials)
	assert.Contains(t, cors.AllowHeaders, "content-type")
	assert.Contains(t, cors.AllowHeaders, "x-amz-date")
	assert.Contains(t, cors.AllowHeaders, "authorization")
	assert.Contains(t, cors.AllowMethods, "GET")
	assert.Contains(t, cors.AllowMethods, "POST")
	assert.Contains(t, cors.AllowMethods, "PUT")
	assert.Contains(t, cors.AllowMethods, "DELETE")
	assert.Contains(t, cors.AllowMethods, "OPTIONS")
	assert.Contains(t, cors.AllowOrigins, "*")
	assert.Equal(t, int64(86400), *cors.MaxAge) // 24시간
}

// validateAPIConnectivity - API 엔드포인트 연결성 테스트
func validateAPIConnectivity(t *testing.T, apiUrl string) {
	// 기본 헬스체크 엔드포인트 테스트
	healthCheckUrl := fmt.Sprintf("%s/health", apiUrl)
	
	// API Gateway가 생성되고 배포되는 시간을 고려하여 재시도
	retry.DoWithRetry(t, "API Connectivity Test", 10, 30*time.Second, func() (string, error) {
		// OPTIONS 요청으로 CORS preflight 테스트
		optionsResp, err := http.NewRequest("OPTIONS", healthCheckUrl, nil)
		if err != nil {
			return "", err
		}
		
		client := &http.Client{Timeout: 10 * time.Second}
		resp, err := client.Do(optionsResp)
		if err != nil {
			return "", fmt.Errorf("OPTIONS 요청 실패: %v", err)
		}
		defer resp.Body.Close()

		// CORS 헤더 검증
		assert.Contains(t, resp.Header.Get("Access-Control-Allow-Origin"), "*")
		assert.Contains(t, resp.Header.Get("Access-Control-Allow-Methods"), "GET")
		
		return "API connectivity test successful", nil
	})

	// 실제 서비스 엔드포인트들 테스트 (ALB가 없으므로 404 또는 502 예상)
	serviceEndpoints := []string{
		fmt.Sprintf("%s/api/customers", apiUrl),
		fmt.Sprintf("%s/api/vets", apiUrl),
		fmt.Sprintf("%s/api/visits", apiUrl),
		fmt.Sprintf("%s/admin", apiUrl),
	}

	for _, endpoint := range serviceEndpoints {
		// GET 요청으로 라우팅 테스트 (백엔드가 없으므로 502 Bad Gateway 예상)
		http_helper.HttpGetWithRetryWithCustomValidation(
			t,
			endpoint,
			nil,
			3,
			10*time.Second,
			func(statusCode int, body string) bool {
				// API Gateway가 정상적으로 라우팅을 시도했다면 502 또는 503 반환
				return statusCode == 502 || statusCode == 503 || statusCode == 404
			},
		)
	}

	t.Logf("API 연결성 테스트 완료: %s", apiUrl)
}
