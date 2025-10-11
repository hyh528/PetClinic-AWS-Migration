# Terraform 로컬 상태 파일 정리 스크립트
# S3 backend 전환을 위해 기존 로컬 상태 파일들을 모두 제거

param(
    [switch]$Force = $false
)

Write-Host "🧹 Terraform 로컬 상태 파일 정리 시작..." -ForegroundColor Yellow

# 정리할 파일/폴더 패턴들
$patterns = @(
    "*.tfstate*",
    ".terraform/",
    ".terraform.backup.*"
)

# 레이어 디렉토리들
$layerDirs = Get-ChildItem -Path "terraform/layers" -Directory

if (-not $Force) {
    Write-Host "⚠️  다음 항목들이 삭제됩니다:" -ForegroundColor Red
    
    foreach ($layerDir in $layerDirs) {
        Write-Host "  📁 $($layerDir.Name):" -ForegroundColor Cyan
        
        foreach ($pattern in $patterns) {
            $items = Get-ChildItem -Path $layerDir.FullName -Filter $pattern -Force -ErrorAction SilentlyContinue
            foreach ($item in $items) {
                Write-Host "    - $($item.Name)" -ForegroundColor Gray
            }
        }
    }
    
    $confirm = Read-Host "`n계속하시겠습니까? (y/N)"
    if ($confirm -ne 'y' -and $confirm -ne 'Y') {
        Write-Host "❌ 작업이 취소되었습니다." -ForegroundColor Red
        exit 1
    }
}

# 실제 정리 작업
$totalDeleted = 0

foreach ($layerDir in $layerDirs) {
    Write-Host "🔄 $($layerDir.Name) 정리 중..." -ForegroundColor Blue
    
    foreach ($pattern in $patterns) {
        $items = Get-ChildItem -Path $layerDir.FullName -Filter $pattern -Force -ErrorAction SilentlyContinue
        
        foreach ($item in $items) {
            try {
                if ($item.PSIsContainer) {
                    Remove-Item -Path $item.FullName -Recurse -Force
                    Write-Host "  ✅ 폴더 삭제: $($item.Name)" -ForegroundColor Green
                } else {
                    Remove-Item -Path $item.FullName -Force
                    Write-Host "  ✅ 파일 삭제: $($item.Name)" -ForegroundColor Green
                }
                $totalDeleted++
            }
            catch {
                Write-Host "  ❌ 삭제 실패: $($item.Name) - $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }
}

Write-Host "`n🎉 정리 완료! 총 $totalDeleted 개 항목이 삭제되었습니다." -ForegroundColor Green
Write-Host "💡 이제 각 레이어에서 'terraform init'을 실행하여 S3 backend로 초기화하세요." -ForegroundColor Yellow

# 다음 단계 안내
Write-Host "`n📋 다음 단계:" -ForegroundColor Cyan
Write-Host "1. Bootstrap 인프라 확인: cd terraform/bootstrap && terraform apply" -ForegroundColor White
Write-Host "2. 레이어별 초기화: cd terraform/layers/01-network && terraform init -backend-config=../../backend.hcl" -ForegroundColor White
Write-Host "3. 배포 실행: terraform plan -var-file=../../envs/dev.tfvars" -ForegroundColor White