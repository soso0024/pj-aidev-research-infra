# main.tf

# LocalStack用のAWSプロバイダーの設定
provider "aws" {
  region                      = "us-east-1"
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  # エンドポイント設定を修正
  endpoints {
    s3  = "http://localhost:4566"
    iam = "http://localhost:4566"
  }

  # LocalStack用の追加設定
  s3_use_path_style = true
}

# S3バケットの作成
resource "aws_s3_bucket" "website_bucket" {
  bucket        = "my-static-website"
  force_destroy = true
}

# バケットの公開アクセス設定
resource "aws_s3_bucket_public_access_block" "website_bucket_public_access" {
  bucket = aws_s3_bucket.website_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# バケットのWebサイト設定
resource "aws_s3_bucket_website_configuration" "website_config" {
  bucket = aws_s3_bucket.website_bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

# バケットポリシー（パブリックアクセスを許可）
resource "aws_s3_bucket_policy" "website_bucket_policy" {
  bucket = aws_s3_bucket.website_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.website_bucket.arn}/*"
      },
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.website_bucket_public_access]
}

# サンプルのHTMLファイルをアップロード
resource "aws_s3_object" "index_html" {
  bucket       = aws_s3_bucket.website_bucket.id
  key          = "index.html"
  content_type = "text/html"
  content      = <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>Static Website on LocalStack S3</title>
</head>
<body>
    <h1>Welcome to my Static Website!</h1>
    <p>This website is hosted on LocalStack S3.</p>
</body>
</html>
EOF
}

resource "aws_s3_object" "error_html" {
  bucket       = aws_s3_bucket.website_bucket.id
  key          = "error.html"
  content_type = "text/html"
  content      = <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>Error - Static Website on LocalStack S3</title>
</head>
<body>
    <h1>Error!</h1>
    <p>Something went wrong. Please try again.</p>
</body>
</html>
EOF
}

# 出力の設定
output "website_endpoint" {
  value = "http://${aws_s3_bucket.website_bucket.id}.s3-website.localhost:4566"
}

output "bucket_name" {
  value = aws_s3_bucket.website_bucket.id
}