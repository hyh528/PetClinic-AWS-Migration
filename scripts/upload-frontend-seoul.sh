#!/bin/bash
# Script to upload frontend static files to Seoul region S3 bucket
# This script uploads the static files from spring-petclinic-api-gateway to the Seoul frontend S3 bucket

# Seoul Region S3 bucket for frontend
S3_BUCKET="petclinic-seoul-dev-frontend-seoul-dev"

# Source directory (relative to project root)
SOURCE_DIR="spring-petclinic-api-gateway/src/main/resources/static"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}========================================"
echo -e "Upload Frontend Files to Seoul S3 Bucket"
echo -e "========================================${NC}"
echo ""

# Check if source directory exists
if [ ! -d "$SOURCE_DIR" ]; then
    echo -e "${RED}❌ Error: Source directory '$SOURCE_DIR' does not exist${NC}"
    echo -e "${YELLOW}Please ensure you're running this script from the project root directory${NC}"
    exit 1
fi

# Check if AWS CLI is configured
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}❌ Error: AWS CLI is not configured or credentials are invalid${NC}"
    echo -e "${YELLOW}Please run 'aws configure' or set up your AWS credentials${NC}"
    exit 1
fi

echo -e "${YELLOW}📁 Source directory: $SOURCE_DIR${NC}"
echo -e "${YELLOW}🪣 Target S3 bucket: s3://$S3_BUCKET/${NC}"
echo ""

# Count files to upload
FILE_COUNT=$(find "$SOURCE_DIR" -type f | wc -l)
echo -e "${CYAN}📊 Files to upload: $FILE_COUNT${NC}"
echo ""

# Confirm upload
echo -e "${YELLOW}⚠️  This will sync all files from '$SOURCE_DIR' to 's3://$S3_BUCKET/'${NC}"
echo -e "${YELLOW}   Existing files in S3 will be overwritten if they differ${NC}"
echo ""
read -p "Do you want to continue? (y/N): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Upload cancelled${NC}"
    exit 0
fi

echo ""
echo -e "${CYAN}⬆️  Starting upload...${NC}"

# Upload files with progress
if aws s3 sync "$SOURCE_DIR" "s3://$S3_BUCKET/" --delete --exact-timestamps; then
    echo ""
    echo -e "${GREEN}✅ Upload completed successfully!${NC}"
    echo ""
    echo -e "${CYAN}🌐 Frontend URL: https://dbj622jzcnms3.cloudfront.net${NC}"
    echo -e "${CYAN}🪣 S3 Bucket: s3://$S3_BUCKET/${NC}"
    echo ""
    echo -e "${YELLOW}💡 Note: CloudFront may take a few minutes to reflect changes${NC}"
else
    echo ""
    echo -e "${RED}❌ Upload failed!${NC}"
    echo -e "${YELLOW}Please check your AWS credentials and permissions${NC}"
    exit 1
fi

echo ""
echo -e "${CYAN}========================================${NC}"