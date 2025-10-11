# =============================================================================
# Lambda GenAI Layer Variables - 怨듭쑀 蹂???쒖뒪???곸슜 (?⑥닚?붾맖)
# =============================================================================
# 紐⑹쟻: shared-variables.tf?먯꽌 ?뺤쓽??怨듯넻 蹂?섎? ?ъ슜?섏뿬 ?쇨????뺣낫
# 怨듭쑀 ?ㅼ젙 (shared-variables.tf?먯꽌 ?꾨떖)
variable "shared_config" {
  description = "怨듭쑀 ?ㅼ젙 ?뺣낫 (shared-variables.tf?먯꽌 ?꾨떖)"
  type = object({
    name_prefix = string
    environment = string
    aws_region  = string
    aws_profile = string
    common_name = string
    common_tags = map(string)
  })
}
# ?곹깭 愿由??ㅼ젙 (shared-variables.tf?먯꽌 ?꾨떖)
variable "state_config" {
  description = "Terraform ?곹깭 愿由??ㅼ젙 (shared-variables.tf?먯꽌 ?꾨떖)"
  type = object({
    bucket_name = string
    region      = string
    profile     = string
  })
}
# =============================================================================
# Lambda GenAI ?덉씠???뱁솕 蹂??(?⑥닚??
# =============================================================================
# Bedrock ?ㅼ젙 (湲곕낯媛믩쭔)
variable "bedrock_model_id" {
  description = "?ъ슜??Bedrock 紐⑤뜽 ID"
  type        = string
  default     = "anthropic.claude-3-haiku-20240307-v1:0"
}
