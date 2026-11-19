output "public_ip" {
  description = "Public IP address of the Ubuntu Management EC2 server"
  value       = aws_instance.management_server.public_ip
}

output "ssh_command" {
  description = "Command to SSH directly into the Management EC2 server"
  value       = "ssh -i ${path.root}/management_key.pem ubuntu@${aws_instance.management_server.public_ip}"
}

output "instant_k8s_test_command" {
  description = "Command to test Kubernetes directly from your local terminal"
  value       = "ssh -i ${path.root}/management_key.pem ubuntu@${aws_instance.management_server.public_ip} 'kubectl get nodes'"
}
