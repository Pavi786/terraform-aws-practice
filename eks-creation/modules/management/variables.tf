variable "cluster_name" {
  description = "The name of the EKS Cluster"
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC where the management EC2 will be launched"
  type        = string
}

variable "public_subnet_id" {
  description = "The public subnet ID where the management EC2 resides"
  type        = string
}

variable "instance_profile_name" {
  description = "The IAM instance profile name for the management EC2"
  type        = string
}

variable "cluster_security_group_id" {
  description = "The EKS control plane security group ID (to allow port 443 inbound)"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance sizing for management server"
  type        = string
  default     = "t3.micro"
}

variable "ready_dependencies" {
  description = "Explicit dependency ensuring cluster, nodes, and admin policy exist before user_data runs"
  type        = any
  default     = []
}
