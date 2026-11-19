output "cluster_role_arn" {
  description = "IAM Role ARN for the EKS Cluster control plane"
  value       = aws_iam_role.cluster.arn
}

output "node_role_arn" {
  description = "IAM Role ARN for the EKS Managed Worker Node group"
  value       = aws_iam_role.nodes.arn
}

output "node_role_name" {
  description = "IAM Role name for the EKS Managed Worker Node group"
  value       = aws_iam_role.nodes.name
}

output "management_role_arn" {
  description = "IAM Role ARN for the Management EC2 server"
  value       = aws_iam_role.management_node.arn
}

output "management_instance_profile_name" {
  description = "Instance Profile name to attach to the Management EC2 server"
  value       = aws_iam_instance_profile.management_profile.name
}

output "node_policy_attachments" {
  description = "Enforces dependency chaining so node groups only launch after policies are attached"
  value = [
    aws_iam_role_policy_attachment.nodes_worker_policy.id,
    aws_iam_role_policy_attachment.nodes_cni_policy.id,
    aws_iam_role_policy_attachment.nodes_ecr_policy.id,
    aws_iam_role_policy_attachment.nodes_ebs_csi_policy.id
  ]
}
