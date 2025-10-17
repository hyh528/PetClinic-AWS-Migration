#!/bin/bash

# Bash script to build and push Docker images for Spring Boot services
# Usage: ./build-and-push-images.sh [-r registry] [-t tag]

set -e

# Default values
REGISTRY="${ECR_REGISTRY:-897722691159.dkr.ecr.ap-southeast-2.amazonaws.com}"
TAG="${GITHUB_SHA:-latest}"
REGION="ap-southeast-2"

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
while getopts "r:t:h" opt; do
    case $opt in
        r) REGISTRY="$OPTARG" ;;
        t) TAG="$OPTARG" ;;
        h)
            echo "Usage: $0 [-r registry] [-t tag]"
            echo "  -r: ECR registry URL (default: ECR_REGISTRY env var or 897722691159.dkr.ecr.ap-southeast-2.amazonaws.com)"
            echo "  -t: Image tag (default: GITHUB_SHA env var or latest)"
            exit 0
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            exit 1
            ;;
    esac
done

# Check if AWS CLI is available
if ! command -v aws &> /dev/null; then
    print_error "AWS CLI is not installed."
    exit 1
fi

print_info "Starting Docker image build and push..."
print_info "Registry: $REGISTRY"
print_info "Tag: $TAG"
print_info "Region: $REGION"

# Login to ECR
print_info "Logging in to ECR..."
if aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$REGISTRY"; then
    print_success "Successfully logged in to ECR"
else
    print_error "Failed to login to ECR"
    exit 1
fi

# Service definitions
services=(
    "spring-petclinic-customers-service:petclinic-customers"
    "spring-petclinic-vets-service:petclinic-vets"
    "spring-petclinic-visits-service:petclinic-visits"
    "spring-petclinic-admin-server:petclinic-admin"
)

# Arrays to store image information
declare -a image_uris
declare -a image_digests

# Build and push each service
for service_pair in "${services[@]}"; do
    service_dir="${service_pair%%:*}"
    service_name="${service_pair##*:}"

    print_info "Building $service_dir..."

    # Check if service directory exists
    if [ ! -d "$service_dir" ]; then
        print_error "Service directory '$service_dir' does not exist."
        exit 1
    fi

    cd "$service_dir"

    # Set executable permission for mvnw
    if [ -f "mvnw" ]; then
        chmod +x mvnw
    fi

    # Build the application
    print_info "Building application with Maven..."
    if [ -f "mvnw" ]; then
        ./mvnw clean package -DskipTests -q
    else
        print_error "Maven wrapper (mvnw) not found in $service_dir"
        exit 1
    fi

    # Build Docker image
    print_info "Building Docker image..."
    if docker build -t "$service_name" .; then
        print_success "Docker image built successfully"
    else
        print_error "Failed to build Docker image for $service_name"
        exit 1
    fi

    # Full ECR repository URL
    ecr_repo="$REGISTRY/$service_name"

    # Tag and push
    print_info "Tagging and pushing to $ecr_repo:$TAG..."
    docker tag "$service_name:latest" "$ecr_repo:$TAG"

    if docker push "$ecr_repo:$TAG"; then
        print_success "Successfully pushed $service_name to ECR"

        # Store image URI for output
        image_uris+=("$ecr_repo@$TAG")
    else
        print_error "Failed to push $service_name to ECR"
        exit 1
    fi

    # Get image digest
    print_info "Getting image digest..."
    digest=$(aws ecr describe-images \
        --repository-name "$service_name" \
        --region "$REGION" \
        --query 'sort_by(imageDetails,& imagePushedAt)[-1].imageDigest' \
        --output text 2>/dev/null || echo "")

    if [ -n "$digest" ]; then
        image_digests+=("$ecr_repo@$digest")
        print_success "Image digest: $digest"
    else
        print_warning "Could not retrieve image digest for $service_name"
        image_digests+=("$ecr_repo@$TAG")
    fi

    cd ..
done

# Create images.properties file for Terraform
print_info "Creating images.properties file..."
cat > images.properties << EOF
customers-service=${image_digests[0]}
vets-service=${image_digests[1]}
visits-service=${image_digests[2]}
admin-server=${image_digests[3]}
EOF

print_success "Images mapping created in images.properties"

# Display results
echo
print_success "Build and push completed successfully!"
echo
print_info "Image URIs with digests:"
for i in "${!services[@]}"; do
    service_pair="${services[$i]}"
    service_name="${service_pair##*:}"
    echo "  $service_name: ${image_digests[$i]}"
done

echo
print_info "Images mapping file (images.properties):"
cat images.properties