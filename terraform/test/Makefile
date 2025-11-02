# Terraform Test Makefile
# 이 Makefile은 Terraform 테스트를 쉽게 실행할 수 있도록 도와줍니다.

.PHONY: help test test-unit test-integration test-network test-security clean deps fmt lint

# 기본 변수
GO_VERSION := 1.21
TEST_TIMEOUT := 30m
AWS_REGION := ap-northeast-2

# 도움말
help: ## 사용 가능한 명령어 표시
	@echo "Terraform Test Commands:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@echo ""

# 의존성 설치
deps: ## Go 모듈 의존성 설치
	@echo "Installing Go dependencies..."
	go mod download
	go mod tidy
	@echo "✅ Dependencies installed"

# 코드 포맷팅
fmt: ## Go 코드 포맷팅
	@echo "Formatting Go code..."
	go fmt ./...
	@echo "✅ Code formatted"

# 린팅
lint: ## Go 코드 린팅 (golangci-lint 필요)
	@echo "Linting Go code..."
	@if command -v golangci-lint >/dev/null 2>&1; then \
		golangci-lint run ./...; \
	else \
		echo "⚠️  golangci-lint not found, skipping lint"; \
	fi

# 모든 테스트 실행
test: deps fmt ## 모든 테스트 실행 (단위 + 통합)
	@echo "Running all tests..."
	go test -v -timeout $(TEST_TIMEOUT) ./...
	@echo "✅ All tests completed"

# 단위 테스트만 실행
test-unit: deps fmt ## 단위 테스트만 실행 (빠른 테스트)
	@echo "Running unit tests..."
	go test -v -short -timeout 10m ./...
	@echo "✅ Unit tests completed"

# 통합 테스트만 실행
test-integration: deps fmt ## 통합 테스트만 실행 (실제 AWS 리소스 생성)
	@echo "Running integration tests..."
	@echo "⚠️  This will create real AWS resources and may incur costs"
	go test -v -timeout $(TEST_TIMEOUT) -run "Integration" ./...
	@echo "✅ Integration tests completed"

# 네트워크 레이어 테스트
test-network: deps fmt ## 네트워크 레이어 테스트만 실행
	@echo "Running network layer tests..."
	go test -v -timeout $(TEST_TIMEOUT) -run "TestNetwork" ./...
	@echo "✅ Network tests completed"

# 보안 레이어 테스트
test-security: deps fmt ## 보안 레이어 테스트만 실행
	@echo "Running security layer tests..."
	go test -v -timeout $(TEST_TIMEOUT) -run "TestSecurity" ./...
	@echo "✅ Security tests completed"

# 데이터베이스 레이어 테스트
test-database: deps fmt ## 데이터베이스 레이어 테스트만 실행
	@echo "Running database layer tests..."
	go test -v -timeout $(TEST_TIMEOUT) -run "TestDatabase" ./...
	@echo "✅ Database tests completed"

# 애플리케이션 레이어 테스트
test-application: deps fmt ## 애플리케이션 레이어 테스트만 실행
	@echo "Running application layer tests..."
	go test -v -timeout $(TEST_TIMEOUT) -run "TestApplication" ./...
	@echo "✅ Application tests completed"

# 특정 테스트 실행
test-specific: deps fmt ## 특정 테스트 실행 (TEST_NAME 변수 필요)
	@if [ -z "$(TEST_NAME)" ]; then \
		echo "❌ TEST_NAME 변수가 필요합니다. 예: make test-specific TEST_NAME=TestNetworkLayer"; \
		exit 1; \
	fi
	@echo "Running specific test: $(TEST_NAME)"
	go test -v -timeout $(TEST_TIMEOUT) -run "$(TEST_NAME)" ./...
	@echo "✅ Test $(TEST_NAME) completed"

# 병렬 테스트 실행
test-parallel: deps fmt ## 병렬로 단위 테스트 실행
	@echo "Running tests in parallel..."
	go test -v -short -parallel 4 -timeout 15m ./...
	@echo "✅ Parallel tests completed"

# 테스트 커버리지 생성
test-coverage: deps fmt ## 테스트 커버리지 리포트 생성
	@echo "Generating test coverage..."
	go test -v -short -coverprofile=coverage.out ./...
	go tool cover -html=coverage.out -o coverage.html
	@echo "✅ Coverage report generated: coverage.html"

# 벤치마크 테스트
test-bench: deps fmt ## 벤치마크 테스트 실행
	@echo "Running benchmark tests..."
	go test -v -bench=. -benchmem ./...
	@echo "✅ Benchmark tests completed"

# 테스트 결과 정리
clean: ## 테스트 결과 파일 정리
	@echo "Cleaning up test artifacts..."
	rm -f coverage.out coverage.html
	go clean -testcache
	@echo "✅ Cleanup completed"

# 테스트 환경 검증
check-env: ## 테스트 환경 검증
	@echo "Checking test environment..."
	@echo "Go version: $(shell go version)"
	@echo "AWS Region: $(AWS_REGION)"
	@if [ -z "$(AWS_PROFILE)" ]; then \
		echo "⚠️  AWS_PROFILE not set, using default credentials"; \
	else \
		echo "AWS Profile: $(AWS_PROFILE)"; \
	fi
	@if command -v terraform >/dev/null 2>&1; then \
		echo "Terraform: $(shell terraform version | head -n1)"; \
	else \
		echo "❌ Terraform not found"; \
		exit 1; \
	fi
	@echo "✅ Environment check completed"

# CI/CD용 테스트 실행
test-ci: deps lint ## CI/CD 환경에서 테스트 실행
	@echo "Running tests for CI/CD..."
	go test -v -short -race -coverprofile=coverage.out ./...
	@echo "✅ CI tests completed"

# 테스트 데이터 생성
generate-test-data: ## 테스트용 더미 데이터 생성
	@echo "Generating test data..."
	@# 여기에 테스트 데이터 생성 로직 추가
	@echo "✅ Test data generated"

# 모든 레이어 순차 테스트
test-layers: deps fmt ## 모든 레이어를 순차적으로 테스트
	@echo "Running layer tests sequentially..."
	$(MAKE) test-network
	$(MAKE) test-security  
	$(MAKE) test-database
	$(MAKE) test-application
	@echo "✅ All layer tests completed"

# 테스트 결과 요약
test-summary: ## 최근 테스트 결과 요약 표시
	@echo "Test Summary:"
	@echo "============="
	@if [ -f coverage.out ]; then \
		echo "Coverage: $(shell go tool cover -func=coverage.out | tail -1 | awk '{print $$3}')"; \
	else \
		echo "No coverage data available"; \
	fi
	@echo ""

# 기본 타겟
.DEFAULT_GOAL := help