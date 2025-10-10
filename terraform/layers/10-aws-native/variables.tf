# ==========================================
# AWS Native Services 통합 레이어 변수 정의
# ==========================================
# 클린 아키텍처 원칙: 의존성 역전 및 설정 외부화

# ==========================================
# 기본 설정 변수 (Foundation)
# ==========================================

variable "project_name" {
  description = "프로젝트 이름"
  type        = string
  default     = "petclinic"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "프로젝트 이름은 소문자, 숫자, 하이픈만 포함할 수 있습니다."
  }
}

variable "environment" {
  description = "환경 (dev, staging, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "환경은 dev, staging, prod 중 하나여야 합니다."
  }
}

variable "name_prefix" {
  description = "리소스 이름 접두사"
  type        = string
  default     = "petclinic-dev"
}

variable "aws_region" {
  description = "AWS 리전"
  type        = string
  default     = "ap-northeast-2"
}

variable "owner" {
  description = "리소스 소유자"
  type        = string
  default     = "team-petclinic"
}

variable "cost_center" {
  description = "비용 센터"
  type        = string
  default     = "training"
}

# ==========================================
# 통합 기능 제어 변수 (Feature Flags)
# ==========================================
# Open/Closed Principle: 기능 추가 시 기존 코드 수정 없이 확장

variable "enable_genai_integration" {
  description = "GenAI 서비스 통합 활성화 여부"
  type        = bool
  default     = true
}

variable "enable_monitoring" {
  description = "모니터링 활성화 여부"
  type        = bool
  default     = true
}

variable "enable_health_checks" {
  description = "헬스체크 활성화 여부"
  type        = bool
  default     = false
}

variable "enable_waf_protection" {
  description = "WAF 보호 활성화 여부"
  type        = bool
  default     = false
}

variable "create_integration_dashboard" {
  description = "통합 대시보드 생성 여부"
  type        = bool
  default     = true
}

# ==========================================
# API Gateway 통합 설정 (Performance Efficiency)
# ==========================================

variable "genai_integration_timeout_ms" {
  description = "GenAI 통합 타임아웃 (밀리초)"
  type        = number
  default     = 29000

  validation {
    condition     = var.genai_integration_timeout_ms >= 50 && var.genai_integration_timeout_ms <= 29000
    error_message = "타임아웃은 50ms에서 29000ms 사이여야 합니다."
  }
}

variable "require_api_key" {
  description = "API 키 요구 여부"
  type        = bool
  default     = false
}

# ==========================================
# 모니터링 및 알람 설정 (Operational Excellence)
# ==========================================

variable "api_gateway_4xx_threshold" {
  description = "API Gateway 4xx 에러 임계값"
  type        = number
  default     = 10
}

variable "lambda_error_threshold" {
  description = "Lambda 에러 임계값"
  type        = number
  default     = 5
}

variable "alarm_actions" {
  description = "알람 액션 (SNS 토픽 ARN 목록)"
  type        = list(string)
  default     = []
}

# ==========================================
# 보안 설정 (Security)
# ==========================================

variable "data_classification" {
  description = "데이터 분류 (public, internal, confidential, restricted)"
  type        = string
  default     = "internal"

  validation {
    condition     = contains(["public", "internal", "confidential", "restricted"], var.data_classification)
    error_message = "데이터 분류는 public, internal, confidential, restricted 중 하나여야 합니다."
  }
}

variable "compliance_requirements" {
  description = "컴플라이언스 요구사항"
  type        = string
  default     = "none"
}

variable "waf_rate_limit" {
  description = "WAF 속도 제한 (5분당 요청 수)"
  type        = number
  default     = 2000

  validation {
    condition     = var.waf_rate_limit >= 100 && var.waf_rate_limit <= 20000000
    error_message = "WAF 속도 제한은 100에서 20,000,000 사이여야 합니다."
  }
}

# ==========================================
# 비용 최적화 설정 (Cost Optimization)
# ==========================================

variable "auto_shutdown_enabled" {
  description = "자동 종료 활성화 여부 (개발 환경용)"
  type        = bool
  default     = true
}

variable "backup_required" {
  description = "백업 필요 여부"
  type        = bool
  default     = false
}

# ==========================================
# 지속 가능성 설정 (Sustainability)
# ==========================================

variable "preferred_instance_types" {
  description = "선호하는 인스턴스 타입 (에너지 효율적인 타입 우선)"
  type        = list(string)
  default     = ["t3.micro", "t3.small", "t4g.micro", "t4g.small"]
}

variable "enable_spot_instances" {
  description = "스팟 인스턴스 사용 활성화 (비용 및 탄소 발자국 절약)"
  type        = bool
  default     = false
}

# ==========================================
# 태그 설정 (Well-Architected Framework 전반)
# ==========================================

variable "additional_tags" {
  description = "추가 태그"
  type        = map(string)
  default     = {}
}

# ==========================================
# 고급 설정 (Advanced Configuration)
# ==========================================

variable "custom_domain_enabled" {
  description = "커스텀 도메인 사용 여부"
  type        = bool
  default     = false
}

variable "custom_domain_name" {
  description = "커스텀 도메인 이름"
  type        = string
  default     = ""
}

variable "certificate_arn" {
  description = "SSL 인증서 ARN"
  type        = string
  default     = ""
}

# ==========================================
# 네트워크 설정 (Reliability)
# ==========================================

variable "enable_vpc_endpoints" {
  description = "VPC 엔드포인트 사용 여부"
  type        = bool
  default     = true
}

variable "enable_private_dns" {
  description = "프라이빗 DNS 사용 여부"
  type        = bool
  default     = true
}

# ==========================================
# 로깅 및 추적 설정 (Operational Excellence)
# ==========================================

variable "log_retention_days" {
  description = "로그 보관 기간 (일)"
  type        = number
  default     = 14

  validation {
    condition = contains([
      1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653
    ], var.log_retention_days)
    error_message = "로그 보관 기간은 CloudWatch Logs에서 지원하는 값이어야 합니다."
  }
}

variable "enable_xray_tracing" {
  description = "X-Ray 추적 활성화 여부"
  type        = bool
  default     = true
}

variable "xray_tracing_mode" {
  description = "X-Ray 추적 모드 (Active 또는 PassThrough)"
  type        = string
  default     = "Active"

  validation {
    condition     = contains(["Active", "PassThrough"], var.xray_tracing_mode)
    error_message = "X-Ray 추적 모드는 Active 또는 PassThrough여야 합니다."
  }
}