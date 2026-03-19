# Zip the Lambda function
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda_function/lambda_function.py"
  output_path = "${path.module}/lambda_function/function.zip"
}

# Lambda function
resource "aws_lambda_function" "ec2_restart" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "${var.environment}-ec2-restart-handler"
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.11"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  timeout          = 300
  memory_size      = 128

  environment {
    variables = {
      INSTANCE_ID   = aws_instance.app_server.id
      SNS_TOPIC_ARN = aws_sns_topic.alerts.arn
      ENVIRONMENT   = var.environment
    }
  }

  tracing_config {
    mode = "Active"
  }

  tags = {
    Name        = "${var.environment}-ec2-restart-handler"
    Environment = var.environment
  }
}

# CloudWatch log group
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${var.environment}-ec2-restart-handler"
  retention_in_days = 30

  tags = {
    Name        = "${var.environment}-lambda-logs"
    Environment = var.environment
  }
}

# API Gateway REST API
resource "aws_api_gateway_rest_api" "sumo_trigger" {
  name        = "${var.environment}-sumo-logic-trigger"
  description = "API Gateway for Sumo Logic to Lambda trigger"
}

# Resource /restart
resource "aws_api_gateway_resource" "restart" {
  rest_api_id = aws_api_gateway_rest_api.sumo_trigger.id
  parent_id   = aws_api_gateway_rest_api.sumo_trigger.root_resource_id
  path_part   = "restart"
}

# POST method
resource "aws_api_gateway_method" "post" {
  rest_api_id   = aws_api_gateway_rest_api.sumo_trigger.id
  resource_id   = aws_api_gateway_resource.restart.id
  http_method   = "POST"
  authorization = "NONE"
}

# Lambda integration
resource "aws_api_gateway_integration" "lambda" {
  rest_api_id             = aws_api_gateway_rest_api.sumo_trigger.id
  resource_id             = aws_api_gateway_resource.restart.id
  http_method             = aws_api_gateway_method.post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.ec2_restart.invoke_arn
}

# Deploy the API
resource "aws_api_gateway_deployment" "prod" {
  rest_api_id = aws_api_gateway_rest_api.sumo_trigger.id
  stage_name  = "prod"

  depends_on = [
    aws_api_gateway_integration.lambda
  ]
}

# Allow API Gateway to invoke Lambda
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ec2_restart.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.sumo_trigger.execution_arn}/*/*"
}