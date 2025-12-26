@echo off
REM Destroy all Terraform layers in Oregon in reverse order
REM Make sure to set AWS credentials before running:
REM set AWS_ACCESS_KEY_ID=your_access_key
REM set AWS_SECRET_ACCESS_KEY=your_secret_key
REM set AWS_DEFAULT_REGION=us-west-2

set LAYERS=12-notification 11-frontend 10-monitoring 09-aws-native 08-api-gateway 07-application 06-lambda-genai 05-cloud-map 04-parameter-store 03-database 02-security 01-network

for %%l in (%LAYERS%) do (
    echo ====================================
    echo Destroying layer: %%l
    echo ====================================
    cd terraform\layers\%%l
    terraform init -backend-config=..\..\backend.hcl -backend-config=backend.config -reconfigure
    if %errorlevel% neq 0 (
        echo Init failed for %%l
        goto :error
    )
    terraform destroy -auto-approve -var-file=..\..\envs\dev.tfvars
    if %errorlevel% neq 0 (
        echo Destroy failed for %%l
        goto :error
    )
    cd ..\..\..
)

echo All layers destroyed successfully.
goto :end

:error
echo Error occurred. Stopping.
cd ..\..\..

:end