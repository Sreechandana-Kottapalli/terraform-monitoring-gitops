output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.monitoring_server.id
}

output "public_ip" {
  description = "EC2 public IP"
  value       = aws_instance.monitoring_server.public_ip
}

output "application_url" {
  description = "Nginx application URL"
  value       = "http://${aws_instance.monitoring_server.public_ip}"
}

output "prometheus_url" {
  description = "Prometheus URL"
  value       = "http://${aws_instance.monitoring_server.public_ip}:9090"
}

output "grafana_url" {
  description = "Grafana URL"
  value       = "http://${aws_instance.monitoring_server.public_ip}:3000"
}