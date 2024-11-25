# main.tf

#####################################
# プロバイダーの設定
#####################################
# LocalStack用のAWSプロバイダーを設定します
# LocalStackはAWSのサービスをローカル環境でエミュレートするツールです
provider "aws" {
  region     = "us-east-1" # リージョンの設定（LocalStackではどのリージョンでも動作します）
  access_key = "test"      # ローカル環境用のダミーアクセスキー
  secret_key = "test"      # ローカル環境用のダミーシークレットキー

  # LocalStack環境では以下の検証をスキップします
  skip_credentials_validation = true # 認証情報の検証をスキップ
  skip_metadata_api_check     = true # メタデータAPIのチェックをスキップ
  skip_requesting_account_id  = true # アカウントIDの要求をスキップ

  # LocalStackの各サービスのエンドポイントを設定
  endpoints {
    lambda = "http://localhost:4566" # Lambda用エンドポイント
    iam    = "http://localhost:4566" # IAM用エンドポイント
    s3     = "http://localhost:4566" # S3用エンドポイント
  }

  # S3のパススタイルアクセスを有効化（LocalStackでの動作に必要）
  s3_use_path_style = true
}

#####################################
# S3バケットの作成
#####################################
# Lambda関数のトリガーとして使用するS3バケットを作成します
resource "aws_s3_bucket" "lambda_trigger_bucket" {
  bucket        = "lambda-trigger-bucket" # バケット名
  force_destroy = true                    # terraform destroyでバケット内のオブジェクトも削除可能に設定
}

#####################################
# IAMロールとポリシーの設定
#####################################
# Lambda関数用のIAMロールを作成します
# このロールによってLambda関数に必要な権限が付与されます
resource "aws_iam_role" "lambda_role" {
  name = "lambda_execution_role"

  # Lambda関数がこのロールを引き受けることができるようにする信頼ポリシー
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole" # ロールを引き受けるためのアクション
        Effect = "Allow"          # 許可を示す
        Principal = {
          Service = "lambda.amazonaws.com" # Lambda サービスにロールの使用を許可
        }
      }
    ]
  })
}

# Lambda関数用のIAMポリシーを作成します
# このポリシーで実際の権限内容を定義します
resource "aws_iam_role_policy" "lambda_policy" {
  name = "lambda_execution_policy"
  role = aws_iam_role.lambda_role.id # 上で作成したロールにアタッチ

  # ポリシーの内容を定義
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",  # CloudWatchロググループの作成権限
          "logs:CreateLogStream", # ログストリームの作成権限
          "logs:PutLogEvents",    # ログの書き込み権限
          "s3:GetObject",         # S3オブジェクトの読み取り権限
          "s3:ListBucket"         # S3バケットの一覧表示権限
        ]
        Resource = "*" # すべてのリソースに対して適用（本番環境ではより制限的にすべき）
      }
    ]
  })
}

#####################################
# Lambda関数のコード定義（Hello World）
#####################################
# Hello World Lambda関数のコードをZIPファイルにパッケージング
data "archive_file" "hello_world_lambda" {
  type        = "zip"                            # ZIPファイルとして作成
  output_path = "${path.module}/hello_world.zip" # 出力先のパス

  # Lambda関数のソースコード
  source {
    content  = <<EOF
// シンプルなHello World Lambda関数
exports.handler = async (event) => {
    // 受け取ったイベントの内容をログに出力
    console.log('Event:', JSON.stringify(event, null, 2));

    // レスポンスの構築
    const response = {
        statusCode: 200,                      // HTTPステータスコード
        body: JSON.stringify({
            message: 'Hello from LocalStack Lambda!',
            timestamp: new Date().toISOString()  // 現在のタイムスタンプ
        })
    };

    return response;
};
EOF
    filename = "index.js" # ファイル名
  }
}

#####################################
# Lambda関数のコード定義（S3トリガー）
#####################################
# S3トリガーで実行されるLambda関数のコードをZIPファイルにパッケージング
data "archive_file" "s3_trigger_lambda" {
  type        = "zip"
  output_path = "${path.module}/s3_trigger.zip"

  # Lambda関数のソースコード
  source {
    content  = <<EOF
// S3イベントを処理するLambda関数
exports.handler = async (event) => {
    // S3イベントの内容をログに出力
    console.log('S3 Event:', JSON.stringify(event, null, 2));

    // イベントレコードをループで処理
    for (const record of event.Records) {
        // バケット名とファイル名をログに出力
        console.log('Bucket:', record.s3.bucket.name);
        console.log('File:', record.s3.object.key);
    }

    // 処理成功のレスポンスを返す
    return {
        statusCode: 200,
        body: JSON.stringify({
            message: 'S3 event processed successfully',
            timestamp: new Date().toISOString()
        })
    };
};
EOF
    filename = "index.js"
  }
}

#####################################
# Lambda関数のリソース作成（Hello World）
#####################################
# Hello World Lambda関数を作成
resource "aws_lambda_function" "hello_world" {
  filename         = data.archive_file.hello_world_lambda.output_path         # デプロイするZIPファイル
  function_name    = "hello_world_function"                                   # 関数名
  role             = aws_iam_role.lambda_role.arn                             # IAMロール
  handler          = "index.handler"                                          # 実行するハンドラー関数
  source_code_hash = data.archive_file.hello_world_lambda.output_base64sha256 # コードの変更検知用ハッシュ
  runtime          = "nodejs18.x"                                             # Node.js 18.xランタイム

  # 環境変数の設定
  environment {
    variables = {
      ENVIRONMENT = "local" # 環境変数の例
    }
  }
}

#####################################
# Lambda関数のリソース作成（S3トリガー）
#####################################
# S3トリガーのLambda関数を作成
resource "aws_lambda_function" "s3_trigger" {
  filename         = data.archive_file.s3_trigger_lambda.output_path
  function_name    = "s3_trigger_function"
  role             = aws_iam_role.lambda_role.arn
  handler          = "index.handler"
  source_code_hash = data.archive_file.s3_trigger_lambda.output_base64sha256
  runtime          = "nodejs18.x"

  # 環境変数の設定
  environment {
    variables = {
      ENVIRONMENT = "local"
    }
  }
}

#####################################
# S3バケットのイベント通知設定
#####################################
# S3バケットにLambda関数をトリガーとして設定
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.lambda_trigger_bucket.id # 設定するバケット

  # Lambda関数の設定
  lambda_function {
    lambda_function_arn = aws_lambda_function.s3_trigger.arn # トリガーとなるLambda関数
    events              = ["s3:ObjectCreated:*"]             # オブジェクト作成時にトリガー
  }
}

#####################################
# Lambda関数のS3トリガー権限設定
#####################################
# S3バケットからLambda関数を呼び出すための権限を設定
resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowS3Invoke"                              # 権限設定の識別子
  action        = "lambda:InvokeFunction"                      # 許可するアクション
  function_name = aws_lambda_function.s3_trigger.function_name # 対象のLambda関数
  principal     = "s3.amazonaws.com"                           # 許可するサービス（S3）
  source_arn    = aws_s3_bucket.lambda_trigger_bucket.arn      # トリガーとなるS3バケット
}

#####################################
# 出力値の設定
#####################################
# 作成したリソースの情報を出力
output "hello_world_lambda_arn" {
  value = aws_lambda_function.hello_world.arn # Hello World Lambda関数のARN
}

output "s3_trigger_lambda_arn" {
  value = aws_lambda_function.s3_trigger.arn # S3トリガーLambda関数のARN
}

output "s3_bucket_name" {
  value = aws_s3_bucket.lambda_trigger_bucket.id # 作成したS3バケットの名前
}
