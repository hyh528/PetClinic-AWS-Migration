# 보안 그룹 모듈의 출력 값들을 정의합니다.

# 생성된 보안 그룹의 ID를 출력합니다.
output "security_group_id" {
  description = "생성된 보안 그룹의 ID입니다."
  
  # sg_type 값에 따라 생성된 리소스의 ID를 조건부로 반환합니다.
  # 팀장님의 스타일을 따라, 3항 연산자를 중첩하여 사용합니다.
  value = var.sg_type == "alb" ? aws_security_group.alb[0].id : (
          var.sg_type == "app" ? aws_security_group.app[0].id : (
          var.sg_type == "db"  ? aws_security_group.db[0].id : (
          var.sg_type == "vpce" ? aws_security_group.vpce[0].id : null
          )
          )
        )
}
