# Admin Server Deployment

## Latest Changes

### 2025-11-06
- Disabled automatic service registration (`AdminServerConfig.registerServices_DISABLED()`)
- Added custom WebClient.Builder with headers for WAF bypass
- Added User-Agent: SpringBootAdmin/3.4.1
- Added Accept: application/json
- Added X-Admin-Request: true

## Build & Deploy

This file triggers CI/CD pipeline to rebuild and deploy admin-server.

Last deployment trigger: 2025-11-06 10:00 UTC
