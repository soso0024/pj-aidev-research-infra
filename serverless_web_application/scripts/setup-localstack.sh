# scripts/setup-localstack.sh
#!/bin/bash

# SES設定
aws --endpoint-url=http://localhost:4566 ses verify-email-identity --email-address noreply@example.com

# S3バケット作成
aws --endpoint-url=http://localhost:4566 s3 mb s3://serverless-web-app-dev-frontend

# Lambda実行ロール作成
aws --endpoint-url=http://localhost:4566 iam create-role \
    --role-name lambda-role \
    --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"lambda.amazonaws.com"},"Action":"sts:AssumeRole"}]}'

# SES権限をロールに追加
aws --endpoint-url=http://localhost:4566 iam put-role-policy \
    --role-name lambda-role \
    --policy-name ses-policy \
    --policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":["ses:SendEmail","ses:SendRawEmail"],"Resource":"*"}]}'

set -e

echo "Waiting for LocalStack to be ready..."
while ! nc -z localhost 4566; do
  sleep 1
done
echo "LocalStack is ready!"

# メールアドレスの検証
echo "Verifying email addresses..."
aws --endpoint-url=http://localhost:4566 --region ap-northeast-1 ses verify-email-identity \
    --email-address noreply@example.com

aws --endpoint-url=http://localhost:4566 --region ap-northeast-1 ses verify-email-identity \
    --email-address test@example.com

# 検証状態の確認
echo "Checking verification status..."
aws --endpoint-url=http://localhost:4566 --region ap-northeast-1 ses get-identity-verification-attributes \
    --identities noreply@example.com test@example.com

echo "Setup completed!"