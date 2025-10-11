package common

import (
	"fmt"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/terraform"
)

// TestConfig 테스트 설정을 관리하는 구조체
type TestConfig struct {
	ModulePath    string
	Environment   string
	TestID        string
	CleanupDelay  time.Duration
	Variables     map[string]interface{}
	Region        string
	Profile       string
}

// NewTestConfig 새로운 테스트 설정을 생성합니다
func NewTestConfig(t *testing.T, modulePath string) *TestConfig {
	// 고유한 테스트 ID 생성 (PR 번호 + 타임스탬프 + 랜덤)
	prNumber := os.Getenv("GITHUB_PR_NUMBER")
	if prNumber == "" {
		prNumber = "local"
	}
	
	testID := fmt.Sprintf("test-%s-%s-%s", 
		prNumber,
		time.Now().Format("20060102-150405"),
		strings.ToLower(random.UniqueId()))

	return &TestConfig{
		ModulePath:   modulePath,
		Environment:  "test",
		TestID:       testID,
		CleanupDelay: 5 * time.Minute,
		Variables:    make(map[string]interface{}),
		Region:       getEnvOrDefault("AWS_REGION", "ap-northeast-1"),
		Profile:      getEnvOrDefault("AWS_PROFILE", "petclinic-dev"),
	}
}

// SetVariable 테스트 변수를 설정합니다
func (tc *TestConfig) SetVariable(key string, value interface{}) *TestConfig {
	tc.Variables[key] = value
	return tc
}

// SetVariables 여러 테스트 변수를 한번에 설정합니다
func (tc *TestConfig) SetVariables(vars map[string]interface{}) *TestConfig {
	for k, v := range vars {
		tc.Variables[k] = v
	}
	return tc
}

// AddTestTags 테스트용 태그를 추가합니다
func (tc *TestConfig) AddTestTags() *TestConfig {
	tags := map[string]string{
		"Purpose":     "terratest",
		"TestID":      tc.TestID,
		"Environment": tc.Environment,
		"CreatedAt":   time.Now().UTC().Format(time.RFC3339),
		"ManagedBy":   "terratest",
	}
	
	// 기존 tags 변수가 있으면 병합, 없으면 새로 생성
	if existingTags, exists := tc.Variables["tags"]; exists {
		if tagMap, ok := existingTags.(map[string]string); ok {
			for k, v := range tags {
				tagMap[k] = v
			}
		}
	} else {
		tc.Variables["tags"] = tags
	}
	
	return tc
}

// GetTerraformOptions Terraform 옵션을 생성합니다
func (tc *TestConfig) GetTerraformOptions() *terraform.Options {
	// 테스트용 태그 자동 추가
	tc.AddTestTags()
	
	return &terraform.Options{
		TerraformDir: tc.ModulePath,
		Vars:         tc.Variables,
		EnvVars: map[string]string{
			"TF_VAR_test_id":     tc.TestID,
			"TF_VAR_environment": tc.Environment,
			"AWS_REGION":         tc.Region,
			"AWS_PROFILE":        tc.Profile,
		},
		// 백엔드 설정 비활성화 (테스트용)
		BackendConfig: map[string]interface{}{
			"bucket": fmt.Sprintf("petclinic-terraform-state-test-%s", tc.TestID),
			"key":    fmt.Sprintf("test/%s/terraform.tfstate", tc.TestID),
			"region": tc.Region,
		},
		Reconfigure: true,
	}
}

// RunTest 테스트를 실행하고 자동으로 정리합니다
func (tc *TestConfig) RunTest(t *testing.T, testFunc func(*testing.T, *terraform.Options)) {
	terraformOptions := tc.GetTerraformOptions()
	
	// 정리 작업 예약 (defer는 역순으로 실행됨)
	defer func() {
		if r := recover(); r != nil {
			t.Logf("Test panicked, cleaning up: %v", r)
		}
		tc.cleanup(t, terraformOptions)
	}()
	
	// 테스트 시작 로그
	t.Logf("Starting test with ID: %s", tc.TestID)
	t.Logf("Module path: %s", tc.ModulePath)
	t.Logf("Region: %s", tc.Region)
	
	// 테스트 실행
	testFunc(t, terraformOptions)
	
	t.Logf("Test completed successfully with ID: %s", tc.TestID)
}

// RunUnitTest 단위 테스트를 실행합니다 (빠른 정리)
func (tc *TestConfig) RunUnitTest(t *testing.T, testFunc func(*testing.T, *terraform.Options)) {
	tc.CleanupDelay = 1 * time.Minute // 단위 테스트는 빠른 정리
	tc.RunTest(t, testFunc)
}

// RunIntegrationTest 통합 테스트를 실행합니다 (느린 정리)
func (tc *TestConfig) RunIntegrationTest(t *testing.T, testFunc func(*testing.T, *terraform.Options)) {
	tc.CleanupDelay = 10 * time.Minute // 통합 테스트는 느린 정리
	tc.RunTest(t, testFunc)
}

// cleanup 테스트 리소스를 정리합니다
func (tc *TestConfig) cleanup(t *testing.T, terraformOptions *terraform.Options) {
	t.Logf("Starting cleanup for test ID: %s", tc.TestID)
	
	// 정리 지연 시간 적용
	if tc.CleanupDelay > 0 {
		t.Logf("Waiting %v before cleanup to ensure resources are ready for deletion", tc.CleanupDelay)
		time.Sleep(tc.CleanupDelay)
	}
	
	// Terraform destroy 실행
	terraform.Destroy(t, terraformOptions)
	
	t.Logf("Cleanup completed for test ID: %s", tc.TestID)
}

// PreserveOnFailure 실패 시 리소스를 보존합니다 (디버깅용)
func (tc *TestConfig) PreserveOnFailure(t *testing.T, preserve bool) *TestConfig {
	if preserve && t.Failed() {
		t.Logf("Test failed, preserving resources with test ID: %s", tc.TestID)
		t.Logf("To manually clean up later, run: terraform destroy in %s", tc.ModulePath)
		
		// 보존 태그 추가
		preserveUntil := time.Now().Add(7 * 24 * time.Hour).Format("2006-01-02")
		tc.SetVariable("preserve_until", preserveUntil)
		
		// 정리 작업 비활성화
		tc.CleanupDelay = 0
	}
	return tc
}

// ValidateOutputs 공통 출력값들을 검증합니다
func ValidateCommonOutputs(t *testing.T, terraformOptions *terraform.Options, expectedOutputs []string) {
	for _, output := range expectedOutputs {
		value := terraform.Output(t, terraformOptions, output)
		if value == "" {
			t.Errorf("Output '%s' should not be empty", output)
		} else {
			t.Logf("✓ Output '%s': %s", output, value)
		}
	}
}

// ValidateResourceTags 리소스 태그를 검증합니다
func ValidateResourceTags(t *testing.T, terraformOptions *terraform.Options, expectedTags map[string]string) {
	// Terraform state에서 리소스 정보 가져오기
	state := terraform.Show(t, terraformOptions)
	
	// 태그 검증 로직 (실제 구현에서는 더 정교한 검증 필요)
	for key, expectedValue := range expectedTags {
		if strings.Contains(state, fmt.Sprintf(`"%s": "%s"`, key, expectedValue)) {
			t.Logf("✓ Tag '%s' found with expected value: %s", key, expectedValue)
		} else {
			t.Errorf("Tag '%s' not found or has incorrect value. Expected: %s", key, expectedValue)
		}
	}
}

// getEnvOrDefault 환경 변수를 가져오거나 기본값을 반환합니다
func getEnvOrDefault(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

// GenerateUniqueResourceName 고유한 리소스 이름을 생성합니다
func GenerateUniqueResourceName(prefix, testID string) string {
	// 리소스 이름 길이 제한 고려 (AWS 리소스별 제한)
	maxLength := 63 // 대부분의 AWS 리소스 이름 제한
	
	name := fmt.Sprintf("%s-%s", prefix, testID)
	if len(name) > maxLength {
		// 테스트 ID를 짧게 자르기
		shortTestID := testID[len(testID)-8:] // 마지막 8자리만 사용
		name = fmt.Sprintf("%s-%s", prefix, shortTestID)
	}
	
	return strings.ToLower(name)
}

// WaitForResourceReady 리소스가 준비될 때까지 대기합니다
func WaitForResourceReady(t *testing.T, description string, maxWaitTime time.Duration, checkFunc func() bool) {
	t.Logf("Waiting for %s (max %v)", description, maxWaitTime)
	
	timeout := time.After(maxWaitTime)
	ticker := time.NewTicker(30 * time.Second)
	defer ticker.Stop()
	
	for {
		select {
		case <-timeout:
			t.Fatalf("Timeout waiting for %s after %v", description, maxWaitTime)
		case <-ticker.C:
			if checkFunc() {
				t.Logf("✓ %s is ready", description)
				return
			}
			t.Logf("Still waiting for %s...", description)
		}
	}
}