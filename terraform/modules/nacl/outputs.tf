# NACL 모듈의 출력 값들을 정의합니다.

# 생성된 네트워크 ACL의 ID를 출력합니다.
output "nacl_id" {
  description = "생성된 네트워크 ACL의 ID입니다."
  value       = aws_network_acl.this.id
}