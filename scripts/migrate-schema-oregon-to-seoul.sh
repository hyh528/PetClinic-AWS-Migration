#!/bin/bash
# =============================================================================
# PetClinic Schema Migration: Oregon to Seoul
# =============================================================================
# Purpose: Export schema from Oregon Aurora DB and import to Seoul Aurora DB
# Prerequisites: MobaXterm SSH connection to bastion hosts

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== PetClinic Schema Migration: Oregon → Seoul ===${NC}"

# =============================================================================
# Step 1: Connect to Oregon Bastion Host
# =============================================================================
echo -e "${YELLOW}Step 1: Connect to Oregon Bastion Host${NC}"
echo "1. Open MobaXterm"
echo "2. Create new SSH session:"
echo "   - Remote host: [Oregon Bastion Public IP]"
echo "   - Username: ec2-user"
echo "   - Key file: [Your SSH key pair]"
echo ""
echo "Once connected, run the following commands on Oregon bastion:"

# Oregon DB Export Commands
cat << 'OREGON_EOF'
# =============================================================================
# Oregon Bastion: Export Schema
# =============================================================================

# Get DB connection details from Parameter Store
DB_ENDPOINT=$(aws ssm get-parameter --name "/petclinic/dev/db/url" --query "Parameter.Value" --output text --region us-west-2 | sed 's|jdbc:mysql://||' | sed 's|:3306/.*||')
DB_USERNAME=$(aws ssm get-parameter --name "/petclinic/dev/db/username" --query "Parameter.Value" --output text --region us-west-2)
DB_SECRET_ARN=$(aws ssm get-parameter --name "/petclinic/dev/db/secrets-manager-name" --query "Parameter.Value" --output text --region us-west-2)
DB_PASSWORD=$(aws secretsmanager get-secret-value --secret-id "$DB_SECRET_ARN" --query "SecretString" --output text --region us-west-2 | jq -r '.password')

echo "Oregon DB Endpoint: $DB_ENDPOINT"
echo "Username: $DB_USERNAME"

# Export schema only (no data) from Oregon DB
mysqldump -h "$DB_ENDPOINT" \
          -P 3306 \
          -u "$DB_USERNAME" \
          -p"$DB_PASSWORD" \
          --no-data \
          --routines \
          --triggers \
          --databases petclinic > petclinic_schema_oregon.sql

echo "Schema exported to: petclinic_schema_oregon.sql"
ls -la petclinic_schema_oregon.sql

# Verify the dump file
head -20 petclinic_schema_oregon.sql
echo "..."
tail -10 petclinic_schema_oregon.sql

OREGON_EOF

echo ""
echo -e "${YELLOW}Step 2: Transfer dump file to Seoul region${NC}"
echo "Transfer the petclinic_schema_oregon.sql file to your Seoul bastion host:"
echo "Options:"
echo "1. Use scp from your local machine:"
echo "   scp -i [key] ec2-user@[oregon-bastion-ip]:~/petclinic_schema_oregon.sql ."
echo "   scp -i [key] petclinic_schema_oregon.sql ec2-user@[seoul-bastion-ip]:~/"
echo ""
echo "2. Use AWS S3 (recommended for security):"
echo "   # On Oregon bastion:"
echo "   aws s3 cp petclinic_schema_oregon.sql s3://your-temp-bucket/schema-migration/ --region us-west-2"
echo "   # On Seoul bastion:"
echo "   aws s3 cp s3://your-temp-bucket/schema-migration/petclinic_schema_oregon.sql . --region ap-northeast-2"

echo ""
echo -e "${YELLOW}Step 3: Connect to Seoul Bastion Host${NC}"
echo "1. Open new MobaXterm session to Seoul bastion:"
echo "   - Remote host: [Seoul Bastion Public IP]"
echo "   - Username: ec2-user"
echo "   - Key file: [Your SSH key pair]"
echo ""
echo "Once connected to Seoul bastion, run the following commands:"

# Seoul DB Import Commands
cat << 'SEOUL_EOF'
# =============================================================================
# Seoul Bastion: Import Schema
# =============================================================================

# Get Seoul DB connection details
DB_ENDPOINT=$(aws ssm get-parameter --name "/petclinic/dev/db/url" --query "Parameter.Value" --output text --region ap-northeast-2 | sed 's|jdbc:mysql://||' | sed 's|:3306/.*||')
DB_USERNAME=$(aws ssm get-parameter --name "/petclinic/dev/db/username" --query "Parameter.Value" --output text --region ap-northeast-2)
DB_SECRET_ARN=$(aws ssm get-parameter --name "/petclinic/dev/db/secrets-manager-name" --query "Parameter.Value" --output text --region ap-northeast-2)
DB_PASSWORD=$(aws secretsmanager get-secret-value --secret-id "$DB_SECRET_ARN" --query "SecretString" --output text --region ap-northeast-2 | jq -r '.password')

echo "Seoul DB Endpoint: $DB_ENDPOINT"
echo "Username: $DB_USERNAME"

# Verify the schema file exists
ls -la petclinic_schema_oregon.sql

# Backup existing Seoul database (optional but recommended)
mysqldump -h "$DB_ENDPOINT" \
          -P 3306 \
          -u "$DB_USERNAME" \
          -p"$DB_PASSWORD" \
          --databases petclinic > petclinic_backup_seoul_before_migration.sql

echo "Backup created: petclinic_backup_seoul_before_migration.sql"

# Import schema to Seoul DB
mysql -h "$DB_ENDPOINT" \
      -P 3306 \
      -u "$DB_USERNAME" \
      -p"$DB_PASSWORD" < petclinic_schema_oregon.sql

echo "Schema imported successfully to Seoul DB"

SEOUL_EOF

echo ""
echo -e "${YELLOW}Step 4: Verify Migration${NC}"
echo "Run these commands on Seoul bastion to verify:"

cat << 'VERIFY_EOF'
# =============================================================================
# Verification Commands
# =============================================================================

# Get Seoul DB connection details
DB_ENDPOINT=$(aws ssm get-parameter --name "/petclinic/dev/db/url" --query "Parameter.Value" --output text --region ap-northeast-2 | sed 's|jdbc:mysql://||' | sed 's|:3306/.*||')
DB_USERNAME=$(aws ssm get-parameter --name "/petclinic/dev/db/username" --query "Parameter.Value" --output text --region ap-northeast-2)
DB_SECRET_ARN=$(aws ssm get-parameter --name "/petclinic/dev/db/secrets-manager-name" --query "Parameter.Value" --output text --region ap-northeast-2)
DB_PASSWORD=$(aws secretsmanager get-secret-value --secret-id "$DB_SECRET_ARN" --query "SecretString" --output text --region ap-northeast-2 | jq -r '.password')

# Check databases
mysql -h "$DB_ENDPOINT" -P 3306 -u "$DB_USERNAME" -p"$DB_PASSWORD" -e "SHOW DATABASES;"

# Check tables in petclinic database
mysql -h "$DB_ENDPOINT" -P 3306 -u "$DB_USERNAME" -p"$DB_PASSWORD" -e "USE petclinic; SHOW TABLES;"

# Check table structures (example for owners table)
mysql -h "$DB_ENDPOINT" -P 3306 -u "$DB_USERNAME" -p"$DB_PASSWORD" -e "USE petclinic; DESCRIBE owners;"

# Count records in each table (should be 0 for schema-only migration)
mysql -h "$DB_ENDPOINT" -P 3306 -u "$DB_USERNAME" -p"$DB_PASSWORD" -e "USE petclinic; SELECT table_name, table_rows FROM information_schema.tables WHERE table_schema = 'petclinic';"

echo "Migration verification complete!"

VERIFY_EOF

echo ""
echo -e "${GREEN}=== Migration Complete ===${NC}"
echo "The petclinic schema has been successfully migrated from Oregon to Seoul."
echo ""
echo -e "${RED}Important Notes:${NC}"
echo "1. This migration exports schema only (no data)"
echo "2. Make sure both bastion hosts have proper IAM permissions"
echo "3. Verify the schema migration before deploying services to Seoul"
echo "4. Clean up temporary files and S3 objects after migration"