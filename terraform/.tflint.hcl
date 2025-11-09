# TFLint Configuration for PetClinic AWS Migration
# https://github.com/terraform-linters/tflint

# TFLint 플러그인 설정
plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

plugin "aws" {
  enabled = true
  version = "0.30.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

# 규칙 설정
config {
  # 모듈 호출 시 변수 검사 활성화
  call_module_type = "all"
  
  # 강제 적용 (경고를 에러로 처리)
  force = false
  
  # 비활성화된 규칙 무시
  disabled_by_default = false
}

# ============================================
# Terraform 기본 규칙
# ============================================

# 선언되지 않은 변수 사용 감지
rule "terraform_unused_declarations" {
  enabled = true
}

# 사용되지 않는 required_providers 감지
rule "terraform_unused_required_providers" {
  enabled = true
}

# 타입이 지정되지 않은 변수 감지
rule "terraform_typed_variables" {
  enabled = true
}

# 명명 규칙 검사
rule "terraform_naming_convention" {
  enabled = true
  
  # 변수명: snake_case
  variable {
    format = "snake_case"
  }
  
  # 로컬 변수명: snake_case
  locals {
    format = "snake_case"
  }
  
  # 출력명: snake_case
  output {
    format = "snake_case"
  }
  
  # 리소스명: snake_case
  resource {
    format = "snake_case"
  }
  
  # 모듈명: snake_case
  module {
    format = "snake_case"
  }
  
  # 데이터 소스명: snake_case
  data {
    format = "snake_case"
  }
}

# 더 이상 사용되지 않는 문법 감지 (TFLint 0.59+ 에서 제거됨)
# rule "terraform_deprecated_syntax" {
#   enabled = true
# }

# 더 이상 사용되지 않는 index 함수 감지 (TFLint 0.59+ 에서 제거됨)
# rule "terraform_deprecated_index" {
#   enabled = true
# }

# 주석 구문 표준화
rule "terraform_comment_syntax" {
  enabled = true
}

# 필수 버전 지정 확인
rule "terraform_required_version" {
  enabled = true
}

# 필수 프로바이더 지정 확인
rule "terraform_required_providers" {
  enabled = true
}

# 표준 모듈 소스 사용 확인
rule "terraform_standard_module_structure" {
  enabled = false  # 우리 프로젝트 구조에 맞지 않음
}

# ============================================
# AWS 관련 규칙
# ============================================

# 잘못된 인스턴스 타입 감지
rule "aws_instance_invalid_type" {
  enabled = true
}

# 더 이상 지원되지 않는 AMI 사용 감지
rule "aws_instance_previous_type" {
  enabled = true
}

# S3 버킷 이름 규칙 검사
rule "aws_s3_bucket_name" {
  enabled = true
}

# RDS 인스턴스 타입 검사
rule "aws_db_instance_invalid_type" {
  enabled = true
}

# ECS 작업 정의 검사 (TFLint 0.59+ 에서 제거됨)
# rule "aws_ecs_task_definition_invalid_cpu" {
#   enabled = true
# }

# Lambda 함수 런타임 검사 (TFLint 0.59+ 에서 제거됨)
# rule "aws_lambda_function_invalid_runtime" {
#   enabled = true
# }

# Route53 레코드 타입 검사 (TFLint 0.59+ 에서 제거됨)
# rule "aws_route53_record_invalid_type" {
#   enabled = true
# }

# ALB 대상 그룹 프로토콜 검사 (TFLint 0.59+ 에서 제거됨)
# rule "aws_alb_target_group_invalid_protocol" {
#   enabled = true
# }

# API Gateway 통합 타입 검사 (TFLint 0.59+ 에서 제거됨)
# rule "aws_api_gateway_integration_invalid_type" {
#   enabled = true
# }

# ============================================
# 비활성화된 규칙 (프로젝트 특성상)
# ============================================

# 리소스 태그 필수 - 일부 리소스는 태그 불필요
rule "aws_resource_missing_tags" {
  enabled = false
}

# 모듈 소스 핀 고정 - 로컬 모듈 사용
rule "terraform_module_pinned_source" {
  enabled = false
}

# 워크스페이스 사용 권장 - 환경별 폴더 사용
rule "terraform_workspace_remote" {
  enabled = false
}
