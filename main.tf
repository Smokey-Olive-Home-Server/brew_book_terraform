

provider "aws" {
  region = "us-west-2"
}

resource "aws_iam_role" "role_for_lambda" {
  name = "myrole"

  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Action" : "sts:AssumeRole",
        "Principal" : {
          "Service" : "lambda.amazonaws.com"
        },
        "Effect" : "Allow",
        "Sid" : ""
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.role_for_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "lambda_policy"
  role = aws_iam_role.role_for_lambda.id

  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [{
      "Effect" : "Allow",
      "Action" : [
        "dynamodb:BatchGetItem",
        "dynamodb:GetItem",
        "dynamodb:Query",
        "dynamodb:Scan",
        "dynamodb:BatchWriteItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem"
      ],
      "Resource" : aws_dynamodb_table.basic_dynamodb_table.arn
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "hello_world" {
  name              = "/aws/lambda/${aws_lambda_function.get_brew_lambda.function_name}"
  retention_in_days = 14
}

data "archive_file" "lambda_zip_file" {
  type        = "zip"
  source_file = "${path.module}/../brew_book_brew_api/target/release/bootstrap"
  output_path = "${path.module}/../brew_book_brew_api/lambda.zip"
}
# 
resource "aws_lambda_function" "get_brew_lambda" {
  filename      = data.archive_file.lambda_zip_file.output_path
  function_name = "brew_book_get_api"
  role          = aws_iam_role.role_for_lambda.arn
  handler       = "hello.handler"
  # The filebase64sha256() function is available in Terraform 0.11.12 and later
  # For Terraform 0.11.11 and earlier, use the base64sha256() function and the file() function:
  # source_code_hash = "${base64sha256(file("lambda_function_payload.zip"))}"
  source_code_hash = filebase64sha256(data.archive_file.lambda_zip_file.output_path)

  runtime = "provided.al2"
}

resource "aws_apigatewayv2_api" "brew_book_apigateway" {
  name                         = "brew_book_apigateway"
  protocol_type                = "HTTP"
  disable_execute_api_endpoint = false
}

resource "aws_apigatewayv2_stage" "apigateway_stage" {
  api_id = aws_apigatewayv2_api.brew_book_apigateway.id

  name        = "ApiGateway_stage"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gw.arn
    format = jsonencode({
      requestId               = "$context.requestId"
      sourceIp                = "$context.identity.sourceIp"
      requestTime             = "$context.requestTime"
      protocol                = "$context.protocol"
      httpMethod              = "$context.httpMethod"
      resourcePath            = "$context.resourcePath"
      routeKey                = "$context.routeKey"
      status                  = "$context.status"
      responseLength          = "$context.responseLength"
      integrationErrorMessage = "$context.integrationErrorMessage"
    })
  }
}

resource "aws_apigatewayv2_integration" "get_brew_integration" {
  api_id             = aws_apigatewayv2_api.brew_book_apigateway.id
  integration_uri    = aws_lambda_function.get_brew_lambda.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

resource "aws_apigatewayv2_integration" "post_brew_integration" {
  api_id             = aws_apigatewayv2_api.brew_book_apigateway.id
  integration_uri    = aws_lambda_function.get_brew_lambda.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "get_brew" {
  api_id    = aws_apigatewayv2_api.brew_book_apigateway.id
  route_key = "GET /brew"
  target    = "integrations/${aws_apigatewayv2_integration.get_brew_integration.id}"
}

resource "aws_apigatewayv2_route" "post_brew" {
  api_id    = aws_apigatewayv2_api.brew_book_apigateway.id
  route_key = "POST /brew"
  target    = "integrations/${aws_apigatewayv2_integration.post_brew_integration.id}"
}

resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_brew_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.brew_book_apigateway.execution_arn}/*/*"
}

resource "aws_cloudwatch_log_group" "api_gw" {
  name              = "/aws/api_gw/${aws_apigatewayv2_api.brew_book_apigateway.name}"
  retention_in_days = 14
}

output "function_name" {
  description = "Name of the Lambda function."
  value       = aws_lambda_function.get_brew_lambda.function_name
}

output "base_url" {
  description = "Base URL for API Gateway stage."
  value       = aws_apigatewayv2_stage.apigateway_stage.invoke_url
}

