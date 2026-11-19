# ==============================================================================
# ROOT MODULE OUTPUTS
# ==============================================================================
output "cluster_name" {
  description = "The name of the EKS Cluster"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "The Kubernetes API server endpoint"
  value       = module.eks.cluster_endpoint
}

output "vpc_id" {
  description = "The ID of the custom VPC"
  value       = module.vpc.vpc_id
}

output "management_server_public_ip" {
  description = "Public IP address of the Ubuntu Management EC2"
  value       = module.management.public_ip
}

output "ssh_to_management_server" {
  description = "Command to SSH into the Management EC2 server"
  value       = module.management.ssh_command
}

output "instant_k8s_test_command" {
  description = "Command to test Kubernetes directly from your local terminal"
  value       = module.management.instant_k8s_test_command
}
