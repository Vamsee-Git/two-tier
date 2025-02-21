output "web_server_1_public_ip" {
  value = aws_instance.web_server_1.public_ip
}

output "web_server_2_public_ip" {
  value = aws_instance.web_server_2.public_ip
}
# Outputs for RDS Instance Endpoint.
output "rds_endpoint" {
  value = aws_db_instance.mysql_db.endpoint
}
 
# Outputs for ALB DNS Name.
output "alb_dns_name" {
  value = aws_lb.web_alb.dns_name
}
