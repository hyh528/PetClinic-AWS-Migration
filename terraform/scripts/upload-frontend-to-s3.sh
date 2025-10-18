#!/bin/bash

# Bash script to upload frontend files to S3 bucket
# Usage: ./upload-frontend-to-s3.sh -b bucket-name [-s source-path] [-p profile-name]

set -e

# Default values
SOURCE_PATH="../../spring-petclinic-api-gateway/src/main/resources/static"
PROFILE_NAME="default"
FORCE=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${CYAN}INFO:${NC} $1"
}

print_success() {
    echo -e "${GREEN}SUCCESS:${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}WARNING:${NC} $1"
}

print_error() {
    echo -e "${RED}ERROR:${NC} $1"
}

# Parse command line arguments
while getopts "b:s:p:fh" opt; do
    case $opt in
        b) BUCKET_NAME="$OPTARG" ;;
        s) SOURCE_PATH="$OPTARG" ;;
        p) PROFILE_NAME="$OPTARG" ;;
        f) FORCE=true ;;
        h)
            echo "Usage: $0 -b bucket-name [-s source-path] [-p profile-name] [-f]"
            echo "  -b: S3 bucket name (required)"
            echo "  -s: Source path for frontend files (default: spring-petclinic-api-gateway/src/main/resources/static)"
            echo "  -p: AWS profile name (default: default)"
            echo "  -f: Force upload without confirmation"
            exit 0
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            exit 1
            ;;
    esac
done

# Check if bucket name is provided
if [ -z "$BUCKET_NAME" ]; then
    print_error "Bucket name is required. Use -b option."
    exit 1
fi

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    print_error "AWS CLI is not installed. Please install it first."
    exit 1
fi

# Check if source path exists
if [ ! -d "$SOURCE_PATH" ]; then
    print_error "Source path '$SOURCE_PATH' does not exist."
    exit 1
fi

print_info "Starting frontend upload to S3..."
print_info "Bucket: $BUCKET_NAME"
print_info "Source: $SOURCE_PATH"
print_info "Profile: $PROFILE_NAME"

# Get AWS account ID for confirmation
if ACCOUNT_ID=$(aws sts get-caller-identity --profile "$PROFILE_NAME" --query Account --output text 2>/dev/null); then
    print_info "AWS Account ID: $ACCOUNT_ID"
else
    print_warning "Could not retrieve AWS account ID. Continuing..."
fi

# Check if bucket exists
if ! aws s3 ls "s3://$BUCKET_NAME" --profile "$PROFILE_NAME" &>/dev/null; then
    print_error "Bucket '$BUCKET_NAME' does not exist or you don't have access to it."
    exit 1
fi

print_success "Bucket exists and is accessible."

# Count files to upload
FILES_COUNT=$(find "$SOURCE_PATH" -type f | wc -l)
print_info "Found $FILES_COUNT files to upload."

# Ask for confirmation unless force flag is set
if [ "$FORCE" = false ]; then
    read -p "Do you want to proceed with uploading $FILES_COUNT files? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Upload cancelled."
        exit 0
    fi
fi

# Upload files
print_info "Uploading files with public-read ACL..."

if aws s3 cp "$SOURCE_PATH" "s3://$BUCKET_NAME/" \
    --recursive \
    --profile "$PROFILE_NAME" \
    --cache-control "max-age=86400"; then

    print_success "Upload completed successfully!"

    # Verify upload
    print_info "Verifying upload..."
    UPLOADED_COUNT=$(aws s3 ls "s3://$BUCKET_NAME/" --profile "$PROFILE_NAME" --recursive | wc -l)
    print_success "Total files in bucket: $UPLOADED_COUNT"

    echo
    print_info "To access your frontend, use the CloudFront distribution URL."
    print_info "You can find the URL in the Terraform outputs after deployment."

else
    print_error "Upload failed."
    exit 1
fi