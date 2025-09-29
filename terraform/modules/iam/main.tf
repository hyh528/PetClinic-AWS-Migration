# CLI 전용 그룹 생성
resource "aws_iam_group" "cli_users" {
  name = var.group_name
}

# 그룹에 AdministratorAccess 정책 연결
resource "aws_iam_group_policy_attachment" "cli_admin" {
  group      = aws_iam_group.cli_users.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# 팀원별 IAM 사용자 생성
# 이 리소스는 콘솔 로그인 프로필(비밀번호)을 생성하지 않으므로 기본적으로 콘솔 접근 권한이 없습니다.
resource "aws_iam_user" "members" {
  for_each = toset(var.team_members)
  name     = "${var.project_name}-${each.value}"
}

# 각 사용자에 대한 AWS 액세스 키 생성 (CLI/API 접근용)
resource "aws_iam_access_key" "member_keys" {
  for_each = aws_iam_user.members
  user     = each.value.name
}

# 그룹 멤버십 (사용자를 그룹에 추가)
resource "aws_iam_group_membership" "cli_users" {
  name  = "${var.project_name}-cli-membership"
  group = aws_iam_group.cli_users.name
  users = [for u in aws_iam_user.members : u.name]
}
