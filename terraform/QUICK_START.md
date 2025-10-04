# 🚀 Terraform 빠른 시작 가이드

## 📋 개요

팀원들이 Terraform 인프라를 안전하게 검증하고 배포할 수 있는 단계별 가이드입니다.

## ⚡ 5분 빠른 검증

### 1단계: 자동 검증 스크립트 실행

```bash
# 프로젝트 루트로 이동
cd terraform

# 검증 스크립트 실행 권한 부여
chmod +x validate-infrastructure.sh

# 전체 인프라 검증 실행
./validate-infrastructure.sh
```

**예상 결과:**
- ✅ 모든 검증 통과: 다음 단계 진행
- ⚠️ 경고만 있음: 주의하며 진행 가능
- ❌ 오류 발견: 팀에 문의 필요

### 2단계: 현재 상태 확인

```bash
# 각 레이어별 현재 상태 확인
cd envs/dev

for layer in network security database application; do
    echo "=== $layer ==="
    cd $layer
    if [ -f terraform.tfstate ]; then
        echo "✅ 배포됨 ($(terraform state list | wc -l) 리소스)"
    else
        echo "❌ 미배포"
    fi
    cd ..
done
```

## 🛠️ 문제 발생 시 즉시 해결

### 자주 발생하는 문제들

#### 1. AWS 자격 증명 오류
```bash
# 현재 자격 증명 확인
aws sts get-caller-identity

# 자격 증명 재설정 (필요시)
aws configure
```

#### 2. Terraform 캐시 문제
```bash
# 특정 레이어에서 오류 발생 시
cd envs/dev/[LAYER_NAME]
rm -rf .terraform
rm .terraform.lock.hcl
terraform init
```

#### 3. 포맷팅 문제
```bash
# 전체 프로젝트 포맷팅
terraform fmt -recursive
```

## 📊 현재 인프라 상태 (2025-10-03 기준)

| 레이어 | 상태 | 비고 |
|--------|------|------|
| 🌐 network | ✅ 안정 | VPC, 서브넷, 게이트웨이 |
| 🔒 security | ✅ 안정 | 보안 그룹, IAM, VPC 엔드포인트 |
| 🗄️ database | ✅ 안정 | Aurora 클러스터 |
| 🚀 application | ⚠️ 검토 필요 | ECS 모듈 이슈 있음 |
| 📊 monitoring | ✅ 안정 | CloudWatch, X-Ray |
| ☁️ aws-native | ✅ 안정 | API Gateway, Parameter Store |
| 💾 state-management | 🆕 신규 | 원격 상태 관리 |

## 🎯 우선순위별 작업 계획

### 🔴 긴급 (오늘 해결)
1. **Application 레이어 오류 수정**
   ```bash
   cd envs/dev/application
   # 오류 확인
   terraform validate
   # 필요시 캐시 정리
   rm -rf .terraform && terraform init
   ```

### 🟡 중요 (이번 주)
2. **상태 관리 인프라 배포**
   ```bash
   cd envs/dev/state-management
   cp terraform.tfvars.example terraform.tfvars
   # terraform.tfvars 수정 후
   terraform init && terraform apply
   ```

3. **원격 상태 마이그레이션**
   ```bash
   # 자동 마이그레이션 스크립트 실행
   ./scripts/migrate-to-remote-state.sh
   ```

### 🟢 일반 (다음 주)
4. **팀 교육 및 문서화**
5. **모니터링 대시보드 설정**
6. **CI/CD 파이프라인 구축**

## 🚨 비상 연락처 및 에스컬레이션

### 즉시 중단해야 하는 상황
- 💰 예상치 못한 고비용 리소스 생성
- 🗑️ 기존 리소스 삭제 계획 감지
- 🔒 보안 설정 변경 감지

### 도움 요청 시 포함할 정보
1. **오류 메시지 전체 복사**
2. **실행한 명령어**
3. **현재 작업 디렉토리**
4. **terraform plan 출력 (있는 경우)**

### 연락 방법
- 💬 팀 슬랙 채널: #devops-terraform
- 📧 이메일: devops@company.com
- 📞 긴급 상황: 영현 (010-xxxx-xxxx)

## 📚 추가 학습 자료

### 필수 문서
- [VALIDATION_GUIDE.md](./VALIDATION_GUIDE.md) - 상세 검증 가이드
- [CURRENT_ISSUES.md](./CURRENT_ISSUES.md) - 알려진 이슈 및 해결방안
- [README.md](./README.md) - 프로젝트 전체 개요

### 외부 자료
- [Terraform 공식 문서](https://www.terraform.io/docs)
- [AWS Provider 문서](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)

## ✅ 일일 체크리스트

### 작업 시작 전
- [ ] 최신 코드 pull 받기
- [ ] AWS 자격 증명 확인
- [ ] 올바른 브랜치에서 작업 중인지 확인

### 작업 중
- [ ] 변경사항은 작은 단위로 나누어 진행
- [ ] terraform plan으로 변경사항 미리 확인
- [ ] 의심스러운 부분은 팀에 문의

### 작업 완료 후
- [ ] terraform validate로 문법 검증
- [ ] AWS 콘솔에서 리소스 상태 확인
- [ ] 변경사항 문서화 및 팀 공유

---

**💡 팁**: 확신이 서지 않으면 언제든 팀에 문의하세요. 인프라는 신중하게 다루는 것이 최선입니다!