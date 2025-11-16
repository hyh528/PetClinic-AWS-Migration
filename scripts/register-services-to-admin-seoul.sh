#!/bin/bash
# Script to manually register services to Spring Boot Admin - Seoul Region
# This is a bash script for Linux/Mac

# Seoul Region URLs - Update these with actual deployed URLs
ADMIN_URL="http://petclinic-seoul-dev-alb-799338015.ap-northeast-2.elb.amazonaws.com/admin"
ALB_DNS="petclinic-seoul-dev-alb-799338015.ap-northeast-2.elb.amazonaws.com"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

echo -e "${CYAN}========================================"
echo -e "Manual Service Registration to Admin UI"
echo -e "Seoul Region (ap-northeast-2)"
echo -e "========================================${NC}"
echo ""

# Define services to register
declare -a services=(
    "customers-service:api/customers"
    "vets-service:api/vets"
    "visits-service:api/visits"
)

registered_count=0
failed_count=0

for service_info in "${services[@]}"; do
    IFS=':' read -r service_name service_path <<< "$service_info"

    echo -e "${YELLOW}Registering ${service_name}...${NC}"

    # Create registration payload
    payload=$(cat <<EOF
{
    "name": "${service_name}",
    "managementUrl": "http://${ALB_DNS}/${service_path}/actuator",
    "healthUrl": "http://${ALB_DNS}/${service_path}/actuator/health",
    "serviceUrl": "http://${ALB_DNS}/${service_path}/"
}
EOF
)

    echo -e "${GRAY}  Payload: ${payload}${NC}"

    # Register the service
    response=$(curl -s -X POST "${ADMIN_URL}/instances" \
        -H "Content-Type: application/json" \
        -d "$payload" \
        -w "\n%{http_code}")

    http_code=$(echo "$response" | tail -n1)
    response_body=$(echo "$response" | sed '$d')

    if [ "$http_code" -eq 201 ] || [ "$http_code" -eq 200 ]; then
        instance_id=$(echo "$response_body" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)
        echo -e "${GREEN}  ✓ Successfully registered ${service_name}${NC}"
        echo -e "${GRAY}    Instance ID: ${instance_id}${NC}"
        ((registered_count++))
    else
        echo -e "${RED}  ✗ Failed to register ${service_name}${NC}"
        echo -e "${RED}    HTTP Status: ${http_code}${NC}"
        echo -e "${RED}    Response: ${response_body}${NC}"
        ((failed_count++))
    fi

    echo ""
done

echo -e "${CYAN}========================================"
echo -e "Registration Summary:"
if [ $registered_count -gt 0 ]; then
    echo -e "${GREEN}  Successfully registered: ${registered_count}${NC}"
else
    echo -e "${GRAY}  Successfully registered: ${registered_count}${NC}"
fi

if [ $failed_count -gt 0 ]; then
    echo -e "${RED}  Failed: ${failed_count}${NC}"
else
    echo -e "${GRAY}  Failed: ${failed_count}${NC}"
fi
echo -e "${CYAN}========================================${NC}"
echo ""
echo -e "${CYAN}Check the admin UI at: ${ADMIN_URL}${NC}"