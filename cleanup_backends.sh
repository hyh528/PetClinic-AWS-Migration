#!/bin/bash

# Backend.tf 파일 주석 간소화 스크립트

LAYERS_DIR="terraform/layers"

# 표준 backend.tf 내용
STANDARD_BACKEND='terraform {
  # Backend configuration injected via: terraform init -backend-config=../../backend.hcl -backend-config=backend.config
  backend "s3" {}
}'

# 모든 레이어의 backend.tf 파일 찾기
find "$LAYERS_DIR" -name "backend.tf" -type f | while read -r file; do
  echo "Processing: $file"
  
  # 백업 생성
  cp "$file" "${file}.backup"
  
  # 새 내용으로 교체
  echo "$STANDARD_BACKEND" > "$file"
  
  echo "✅ Updated: $file"
done

echo ""
echo "=========================================="
echo "Backend.tf 파일 간소화 완료!"
echo "=========================================="
echo ""
echo "변경된 파일 수: $(find "$LAYERS_DIR" -name "backend.tf" -type f | wc -l)"
echo ""
echo "백업 파일: *.backup"
echo "확인 후 백업 파일 삭제: find $LAYERS_DIR -name '*.backup' -delete"
