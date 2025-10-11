# 🚀 Quick Start Guide

## 📋 사전 요구사항

### 1. 필수 도구 설치

#### Terraform 설치
```bash
# Windows (Chocolatey)
choco install terraform

# Windows (Scoop)
scoop install terraform

# macOS (Homebrew)
brew install terraform

# Linux (Ubuntu/Debian)
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform
```

#### AWS CLI 설치
```bash
# Windows
winget install Amazon.AWSCLI

# macOS
brew install awscli

# Linux
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

### 2. 설치 확인
```bash
# Terraform 버전 확인
terraform version

# AWS CLI 버전 확인
aws --version
```

### 3. AWS 자격 증명 설정
```bash
# AWS 자격 증명 설정
aws configure

# 설정 확인
aws sts get-caller-identity
```

## 🏗️ 빠른 시작

### 1. 모든 레이어 초기화
```bash
cd terraform
bash scripts/init-all.sh dev
```

### 2. 모든 레이어 Plan 실행
```bash
bash scripts/plan-all.sh dev
```

### 3. 모든 레이어 Apply 실행 (선택적)
```bash
bash scripts/apply-all.sh dev
```

## 🔧 문제 해결

### Terraform 명령어를 찾을 수 없음
```bash
# PATH 확인
echo $PATH

# Terraform 설치 위치 확인
which terraform

# Windows에서 PATH 추가
setx PATH "%PATH%;C:\terraform"
```

### AWS 자격 증명 오류
```bash
# 자격 증명 재설정
aws configure

# 프로파일 확인
aws configure list

# 특정 프로파일 사용
export AWS_PROFILE=your-profile-name
```

## 📚 추가 문서

- [전체 README](./README.md)
- [마이그레이션 가이드](./MIGRATION_GUIDE.md)
- [운영 가이드](./OPERATIONS_GUIDE.md)
- [레이어 실행 순서](./docs/LAYER_EXECUTION_ORDER.md)