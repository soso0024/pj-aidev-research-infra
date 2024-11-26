
# infrastructure/outputs.tf
output "api_endpoint" {
  value = aws_apigatewayv2_api.main.api_endpoint
}

output "frontend_url" {
  value = "http://${aws_s3_bucket.frontend.website_endpoint}"
}
