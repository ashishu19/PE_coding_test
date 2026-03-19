output "ec2_instance_id" {
  description = "EC2 Instance ID"
  value       = aws_instance.app_server.id
}

output "ec2_public_ip" {
  description = "EC2 Public IP"
  value       = aws_instance.app_server.public_ip
}

output "sns_topic_arn" {
  description = "SNS Topic ARN"
  value       = aws_sns_topic.alerts.arn
}

output "lambda_function_name" {
  description = "Lambda Function Name"
  value       = aws_lambda_function.ec2_restart.function_name
}

output "lambda_function_arn" {
  description = "Lambda Function ARN"
  value       = aws_lambda_function.ec2_restart.arn
}

output "api_gateway_url" {
  description = "API Gateway URL to paste into Sumo Logic webhook"
  value       = "${aws_api_gateway_deployment.prod.invoke_url}/restart"
}