# Spring Boot Admin Service Registration

This directory contains scripts for manually registering microservices to the Spring Boot Admin UI.

## Overview

The services have been configured to auto-register with the Admin server, but if that fails or you need to manually register them, you can use the scripts provided here.

## Successfully Registered Services

✅ **customers-service** - Instance ID: `04af7f694f37`
✅ **vets-service** - Instance ID: `4b982232e776`
✅ **visits-service** - Instance ID: `c8a67effe979`

## Available Scripts

### 1. Register Services (PowerShell - Windows)
```powershell
powershell -ExecutionPolicy Bypass -File scripts/register-services-to-admin.ps1
```

### 2. Register Services (Bash - Linux/Mac)
```bash
chmod +x scripts/register-services-to-admin.sh
./scripts/register-services-to-admin.sh
```

### 3. Check Registration Status (PowerShell - Windows)
```powershell
powershell -ExecutionPolicy Bypass -File scripts/check-admin-registration.ps1
```

## Admin UI Access

**Admin Dashboard URL:** http://petclinic-dev-alb-1211424104.us-west-2.elb.amazonaws.com/admin

## Service Configuration

Each service is registered with the following URLs:

### Customers Service
- **Service URL:** http://petclinic-dev-alb-1211424104.us-west-2.elb.amazonaws.com/api/customers/
- **Health URL:** http://petclinic-dev-alb-1211424104.us-west-2.elb.amazonaws.com/api/customers/actuator/health
- **Management URL:** http://petclinic-dev-alb-1211424104.us-west-2.elb.amazonaws.com/api/customers/actuator

### Vets Service
- **Service URL:** http://petclinic-dev-alb-1211424104.us-west-2.elb.amazonaws.com/api/vets/
- **Health URL:** http://petclinic-dev-alb-1211424104.us-west-2.elb.amazonaws.com/api/vets/actuator/health
- **Management URL:** http://petclinic-dev-alb-1211424104.us-west-2.elb.amazonaws.com/api/vets/actuator

### Visits Service
- **Service URL:** http://petclinic-dev-alb-1211424104.us-west-2.elb.amazonaws.com/api/visits/
- **Health URL:** http://petclinic-dev-alb-1211424104.us-west-2.elb.amazonaws.com/api/visits/actuator/health
- **Management URL:** http://petclinic-dev-alb-1211424104.us-west-2.elb.amazonaws.com/api/visits/actuator

## Status Information

Services may initially show as **OFFLINE** status. This is normal and will update to **UP** once:
1. The services are fully started and healthy
2. The Admin server completes its first health check (configured to run every 30 seconds)
3. Network connectivity is established between Admin server and services

## Troubleshooting

### Services Show as OFFLINE
- Wait 30-60 seconds for the Admin server to perform its first health check
- Verify services are running: Check ECS tasks in AWS Console
- Test health endpoints directly:
  ```bash
  curl http://petclinic-dev-alb-1211424104.us-west-2.elb.amazonaws.com/api/customers/actuator/health
  curl http://petclinic-dev-alb-1211424104.us-west-2.elb.amazonaws.com/api/vets/actuator/health
  curl http://petclinic-dev-alb-1211424104.us-west-2.elb.amazonaws.com/api/visits/actuator/health
  ```

### Services Not Appearing in Admin UI
- Run the registration script again to re-register
- Check Admin server logs for errors
- Verify the ALB DNS name is correct and accessible

### Auto-Registration Not Working
The services are configured with `spring.boot.admin.client` settings in their `application.yml` files. If auto-registration fails:
1. Check service logs for registration errors
2. Verify the Admin server URL is accessible from the services
3. Use manual registration scripts as a fallback

## Spring Boot Admin Configuration

The Admin server is configured with:
- **Discovery:** Disabled (manual registration mode)
- **Status Check Interval:** 30 seconds
- **Info Update Interval:** 60 seconds
- **Default Timeout:** 15 seconds
- **Status Lifetime:** 5 minutes (300 seconds)

## API Endpoints

### Register a Service Manually
```bash
curl -X POST http://petclinic-dev-alb-1211424104.us-west-2.elb.amazonaws.com/admin/instances \
  -H "Content-Type: application/json" \
  -d '{
    "name": "service-name",
    "managementUrl": "http://host/actuator",
    "healthUrl": "http://host/actuator/health",
    "serviceUrl": "http://host/"
  }'
```

### List All Registered Instances
```bash
curl http://petclinic-dev-alb-1211424104.us-west-2.elb.amazonaws.com/admin/instances
```

### Get Instance Details
```bash
curl http://petclinic-dev-alb-1211424104.us-west-2.elb.amazonaws.com/admin/instances/{instance-id}
```

### Deregister a Service
```bash
curl -X DELETE http://petclinic-dev-alb-1211424104.us-west-2.elb.amazonaws.com/admin/instances/{instance-id}
```

## Additional Notes

- Services remain registered even if they go offline temporarily
- The Admin server will continue monitoring and will update status when services come back online
- Registration persists in the Admin server's memory (cleared on Admin server restart)
- For production, consider enabling auto-registration with proper authentication