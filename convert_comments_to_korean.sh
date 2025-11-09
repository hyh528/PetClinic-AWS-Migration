#!/bin/bash

# Backend.tf 주석을 한국어로 변경하는 스크립트

LAYERS_DIR="terraform/layers"

# 한국어 backend.tf 내용
KOREAN_BACKEND='terraform {
  # Backend 설정은 init 시 주입: terraform init -backend-config=../../backend.hcl -backend-config=backend.config
  backend "s3" {}
}'

# 모든 레이어의 backend.tf 파일 찾기
find "$LAYERS_DIR" -name "backend.tf" -type f | while read -r file; do
  echo "처리 중: $file"
  
  # 새 내용으로 교체
  echo "$KOREAN_BACKEND" > "$file"
  
  echo "✅ 완료: $file"
done

echo ""
echo "=========================================="
echo "Backend.tf 주석 한국어 변환 완료!"
echo "=========================================="
echo ""
echo "변경된 파일 수: $(find "$LAYERS_DIR" -name "backend.tf" -type f | wc -l)"
