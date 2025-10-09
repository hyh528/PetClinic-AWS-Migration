# ==========================================
# DB Password Secret 관리 (AWS Secrets Manager)
# ==========================================
# 실무 DevOps 표준 방식: 시크릿은 Terraform 외부에서 관리
#
# 시크릿 생성 절차:
# 1. AWS Console > Secrets Manager > "Store a new secret"
# 2. Secret type: "Other type of secret"
# 3. Key: "password", Value: 실제 DB 비밀번호
# 4. Secret name: "petclinic/dev/db-password"
# 5. 암호화 키: aws/secretsmanager (기본)
# 6. 태그 추가 (Project, Environment 등)
#
# 또는 AWS CLI로 생성:
# aws secretsmanager create-secret \
#   --name "petclinic/dev/db-password" \
#   --secret-string '{"password":"your_actual_password"}' \
#   --tags '[{"Key":"Project","Value":"petclinic"},{"Key":"Environment","Value":"dev"}]'
#
# CI/CD에서 자동화:
# - GitHub Actions: secrets.PETCLINIC_DB_PASSWORD
# - Jenkins: credentials plugin
# - AWS CodeBuild: parameter store 또는 secrets manager
#
# 보안 고려사항:
# - 시크릿은 Terraform state에 저장되지 않음
# - IAM 정책으로 접근 제어
# - CloudTrail로 감사 로그 확인
# - 정기적인 시크릿 로테이션 권장

data "aws_secretsmanager_secret_version" "db_password" {
  # 시크릿 ARN 또는 이름으로 참조
  # ARN 사용 시 리전/계정 의존성 제거
  secret_id = "petclinic/dev/db-password"

  # 선택사항: 특정 버전 지정 (기본은 AWSCURRENT)
  # version_id = "uuid"

  # depends_on으로 명시적 의존성 설정 가능
  # depends_on = []
}