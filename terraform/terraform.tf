provider "aws" {
  region  = "us-east-1"
  version = "~> 2.0"
}

terraform {
  backend "s3" {
    bucket = "tfstate3671272409937123"
    key    = "iam"
    region = "eu-west-2"
  }
}

locals {
  function_name = "${terraform.workspace}_java_example"
}

resource "aws_apigatewayv2_api" "example" {
  name          = "${terraform.workspace} example http api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_route" "example" {
  api_id    = aws_apigatewayv2_api.example.id
  route_key = "ANY /{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.example.id}"
}

resource "aws_apigatewayv2_integration" "example" {
  api_id                 = aws_apigatewayv2_api.example.id
  integration_type       = "AWS_PROXY"
  payload_format_version = "2.0"
  connection_type        = "INTERNET"
  description            = "example lambda integration"
  integration_method     = "ANY"
  integration_uri        = aws_lambda_function.example.arn
}

resource "aws_apigatewayv2_stage" "example" {
  api_id      = aws_apigatewayv2_api.example.id
  name        = "$default"
  auto_deploy = true
}

#data "archive_file" "lambda_zip" {
#  type        = "zip"
#  source_dir  = "../python/"
#  output_path = "../${terraform.workspace}_python.zip"
#}

resource "aws_iam_role" "iam_for_lambda" {
  name = "${terraform.workspace}_iam_for_lambda"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "example" {
  filename         = "../java/target/javalambda-0.0.1-SNAPSHOT.jar" #data.archive_file.lambda_zip.output_path
  function_name    = local.function_name
  runtime          = "java8"
  timeout          = 5
  handler          = "com.demo.lambda.Handler"
  role             = aws_iam_role.iam_for_lambda.arn
  source_code_hash = filebase64sha256("../java/target/javalambda-0.0.1-SNAPSHOT.jar") #data.archive_file.lambda_zip.output_base64sha256
  depends_on       = [aws_iam_role_policy_attachment.lambda_logs, aws_cloudwatch_log_group.example]
}

resource "aws_cloudwatch_log_group" "example" {
  name              = "/aws/lambda/${local.function_name}"
  retention_in_days = 1
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

resource "aws_lambda_permission" "example" {
  statement_id  = "allow_apigw_invoke"
  function_name = local.function_name
  action        = "lambda:InvokeFunction"
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${aws_apigatewayv2_api.example.id}/*/*/{proxy+}"
}

output "url" {
  value = aws_apigatewayv2_stage.example.invoke_url
}
