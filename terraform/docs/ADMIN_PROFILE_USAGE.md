# Admin 프로파일 사용법 (영현님용)

## 🎯 목적
영현님이 모든 레이어를 확인할 수 있도록 admin 프로파일을 생성했습니다.
팀원들의 기존 프로파일은 그대로 유지됩니다.

## 🔧 사용 방법

### 영현님 사용 시
```bash
# 환경 변수 설정 (자동으로 설정됨)
export AWS_PROFILE=petclinic-dev-admin

# 모든 레이어 확인 가능
cd envs/dev/network && terraform plan
cd envs/dev/security && terraform plan
cd envs/dev/database && terraform plan
cd envs/dev/application && terraform plan
```

### 팀원들 사용 시 (기존 방식 유지)
```bash
# 휘권 (보안)
export AWS_PROFILE=petclinic-hwigwon
cd envs/dev/security && terraform plan

# 석겸 (애플리케이션)  
export AWS_PROFILE=petclinic-seokgyeom
cd envs/dev/application && terraform plan

# 준제 (데이터베이스)
export AWS_PROFILE=petclinic-jungsu
cd envs/dev/database && terraform plan

# 영현 (네트워크) - 기존 프로파일도 사용 가능
export AWS_PROFILE=petclinic-yeonghyeon
cd envs/dev/network && terraform plan
```

## 📋 프로파일 목록

| 팀원 | 역할 | 프로파일 | 접근 레이어 |
|------|------|----------|-------------|
| 영현 | 인프라 총괄 | petclinic-dev-admin | 모든 레이어 |
| 영현 | 네트워크 | petclinic-yeonghyeon | network |
| 휘권 | 보안 | petclinic-hwigwon | security |
| 석겸 | 애플리케이션 | petclinic-seokgyeom | application |
| 준제 | 데이터베이스 | petclinic-jungsu | database |

## 🔄 프로파일 전환

```bash
# Admin 모드 (영현님 전체 확인용)
export AWS_PROFILE=petclinic-dev-admin

# 개별 작업 모드 (기존 방식)
export AWS_PROFILE=petclinic-yeonghyeon

# 현재 프로파일 확인
aws sts get-caller-identity
```

## 💡 팁

1. **전체 확인 시**: admin 프로파일 사용
2. **개별 작업 시**: 기존 개인 프로파일 사용  
3. **팀원들**: 기존 방식 그대로 사용
4. **문제 발생 시**: admin 프로파일로 디버깅

