#!/bin/bash

# terraform-docs 자동 생성 스크립트
# 모든 모듈과 환경별 디렉터리에 README.md를 자동 생성합니다.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "🔄 Terraform 문서 자동 생성 시작..."

# 모듈 문서 생성
echo "📚 모듈 문서 생성 중..."
find "$PROJECT_ROOT/modules" -name "main.tf" -type f | while read -r tf_file; do
    module_dir="$(dirname "$tf_file")"
    echo "  - $module_dir"

    # terraform-docs 실행
    if command -v terraform-docs &> /dev/null; then
        terraform-docs markdown table --output-file README.md "$module_dir"
    else
        echo "⚠️  terraform-docs가 설치되지 않았습니다. 다음 명령어로 설치하세요:"
        echo "   go install github.com/terraform-docs/terraform-docs@latest"
        exit 1
    fi
done

# 환경별 디렉터리 문서 생성 (선택사항)
echo "🏗️ 환경별 디렉터리 문서 생성 중..."
for env in dev staging prod; do
    if [ -d "$PROJECT_ROOT/envs/$env" ]; then
        echo "  - envs/$env"

        # 각 레이어의 README 생성
        find "$PROJECT_ROOT/envs/$env" -name "main.tf" -type f | while read -r tf_file; do
            layer_dir="$(dirname "$tf_file")"
            echo "    - $layer_dir"

            if command -v terraform-docs &> /dev/null; then
                terraform-docs markdown table --output-file README.md "$layer_dir"
            fi
        done
    fi
done

echo "✅ Terraform 문서 생성 완료!"
echo "📖 생성된 문서들을 확인하세요."