# PowerShell script to generate AWS architecture diagram using MCP

$python_code = @"
from diagrams import Diagram
from diagrams.aws.network import InternetGateway, ALB, NATGateway
from diagrams.aws.compute import ECS
from diagrams.aws.database import Aurora

with Diagram("Spring PetClinic Network Architecture", show=False):
    igw = InternetGateway("IGW")
    alb_a = ALB("ALB AZ-a")
    nat_a = NATGateway("NAT AZ-a")
    alb_c = ALB("ALB AZ-c")
    nat_c = NATGateway("NAT AZ-c")
    ecs_a = ECS("ECS AZ-a")
    ecs_c = ECS("ECS AZ-c")
    aurora_a = Aurora("Aurora AZ-a")
    aurora_c = Aurora("Aurora AZ-c")

    igw >> alb_a
    igw >> alb_c
    alb_a >> ecs_a
    alb_c >> ecs_c
    ecs_a >> aurora_a
    ecs_c >> aurora_c
    nat_a >> ecs_a
    nat_c >> ecs_c
"@

# JSON RPC messages for MCP

$init = '{"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "2024-11-05", "capabilities": {}, "clientInfo": {"name": "diagram-generator", "version": "1.0"}}}'

$call = '{"jsonrpc": "2.0", "id": 2, "method": "tools/call", "params": {"name": "generate_diagram", "arguments": {"code": "' + $python_code.Replace('"', '\"').Replace("`n", "\n").Replace("`r", "") + '"}}}'

# Combine messages

$input = $init + "`n" + $call + "`n"

# Run the MCP server and capture output

$result = $input | & uv tool run --from awslabs.aws-diagram-mcp-server@latest awslabs.aws-diagram-mcp-server.exe 2>&1

# Save the output

$result | Out-File -FilePath "docs/network-architecture-diagram-output.txt" -Encoding UTF8

Write-Host "AWS architecture diagram generated using MCP. Check docs/network-architecture-diagram.png and docs/network-architecture-diagram-output.txt"