# ==========================================
# Monitoring 레이어 변수 정의
# ==========================================

variable "alert_email" {
  description = "알람 알림을 받을 이메일 주소"
  type        = string
  default     = "admin@petclinic.local"
}