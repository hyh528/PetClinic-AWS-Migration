# PowerShell script to upload frontend files to S3 bucket
# Usage: .\upload-frontend-to-s3.ps1 -BucketName "your-bucket-name" -SourcePath "path/to/frontend/files"

param(
    [Parameter(Mandatory=$true)]
    [string]$BucketName,

    [Parameter(Mandatory=$false)]
    [string]$SourcePath = "spring-petclinic-api-gateway/src/main/resources/static",

    [Parameter(Mandatory=$false)]
    [string]$ProfileName = "default",

    [Parameter(Mandatory=$false)]
    [switch]$Force
)

# Check if AWS CLI is installed
if (!(Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Error "AWS CLI is not installed. Please install it first."
    exit 1
}

# Check if source path exists
if (!(Test-Path $SourcePath)) {
    Write-Error "Source path '$SourcePath' does not exist."
    exit 1
}

Write-Host "Starting frontend upload to S3..." -ForegroundColor Green
Write-Host "Bucket: $BucketName" -ForegroundColor Yellow
Write-Host "Source: $SourcePath" -ForegroundColor Yellow
Write-Host "Profile: $ProfileName" -ForegroundColor Yellow

# Get AWS account ID for confirmation
try {
    $accountId = aws sts get-caller-identity --profile $ProfileName --query Account --output text 2>$null
    Write-Host "AWS Account ID: $accountId" -ForegroundColor Cyan
} catch {
    Write-Warning "Could not retrieve AWS account ID. Continuing..."
}

# Check if bucket exists
$bucketExists = aws s3 ls "s3://$BucketName" --profile $ProfileName --region us-west-2 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Error "Bucket '$BucketName' does not exist or you don't have access to it."
    exit 1
}

Write-Host "Bucket exists and is accessible." -ForegroundColor Green

# Count files to upload
$filesToUpload = Get-ChildItem -Path $SourcePath -Recurse -File | Measure-Object | Select-Object -ExpandProperty Count
Write-Host "Found $filesToUpload files to upload." -ForegroundColor Cyan

if (!$Force) {
    $confirmation = Read-Host "Do you want to proceed with uploading $filesToUpload files? (y/N)"
    if ($confirmation -ne 'y' -and $confirmation -ne 'Y') {
        Write-Host "Upload cancelled." -ForegroundColor Yellow
        exit 0
    }
}

# Set ACL to public-read for static website hosting
Write-Host "Uploading files with public-read ACL..." -ForegroundColor Green

# Upload files recursively
try {
    aws s3 cp $SourcePath "s3://$BucketName/" --recursive --acl public-read --profile $ProfileName --cache-control "max-age=86400" --exclude "*.DS_Store" --exclude "*.git*" --region us-west-2  # 로컬 테스트용으로 캐시 시간 단축

    if ($LASTEXITCODE -eq 0) {
        Write-Host "Upload completed successfully!" -ForegroundColor Green

        # Verify upload by listing some files
        Write-Host "Verifying upload..." -ForegroundColor Cyan
        $uploadedFiles = aws s3 ls "s3://$BucketName/" --profile $ProfileName --region us-west-2 --recursive | Measure-Object | Select-Object -ExpandProperty Count
        Write-Host "Total files in bucket: $uploadedFiles" -ForegroundColor Green

        # Show bucket website URL if configured
        Write-Host "`nTo access your frontend, use the CloudFront distribution URL." -ForegroundColor Cyan
        Write-Host "You can find the URL in the Terraform outputs after deployment." -ForegroundColor Cyan

    } else {
        Write-Error "Upload failed with exit code $LASTEXITCODE"
        exit 1
    }
} catch {
    Write-Error "Upload failed: $_"
    exit 1
}