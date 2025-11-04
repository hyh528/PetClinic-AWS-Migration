 module "ecs_cluster" {
   source = "../../../modules/ecs-cluster"

   cluster_name             = "petclinic-cluster"
   task_execution_role_name = "petclinic-ecs-task-execution-role-v2"
   ecs_secrets_policy_arn   = data.terraform_remote_state.security.outputs.ecs_secrets_policy_arn
   ecs_ssm_policy_arn       = data.terraform_remote_state.security.outputs.ecs_ssm_policy_arn
 }