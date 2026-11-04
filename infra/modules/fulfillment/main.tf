variable "environment" {
  type = string
}

locals {
  name = "acme-${var.environment}"
}

resource "aws_s3_bucket" "manifests" {
  bucket = "${local.name}-shipment-manifests"
}

resource "aws_s3_bucket_public_access_block" "manifests" {
  bucket                  = aws_s3_bucket.manifests.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "manifests" {
  bucket = aws_s3_bucket.manifests.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_sqs_queue" "dispatch_dlq" {
  name = "${local.name}-dispatch-dlq"
}

resource "aws_sqs_queue" "dispatch" {
  name = "${local.name}-dispatch"
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dispatch_dlq.arn
    maxReceiveCount     = 5
  })
}

resource "aws_dynamodb_table" "shipments" {
  name         = "${local.name}-shipments"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "tracking_number"

  attribute {
    name = "tracking_number"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }
}

resource "aws_iam_role" "lambda" {
  name = "${local.name}-fulfillment-lambda"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" }, Action = "sts:AssumeRole" }]
  })
}

resource "aws_iam_role_policy_attachment" "logs" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "lambda" {
  statement {
    actions   = ["s3:PutObject", "s3:GetObject"]
    resources = ["${aws_s3_bucket.manifests.arn}/*"]
  }
  statement {
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.dispatch.arn]
  }
  statement {
    actions   = ["dynamodb:PutItem", "dynamodb:GetItem"]
    resources = [aws_dynamodb_table.shipments.arn]
  }
}

resource "aws_iam_role_policy" "lambda" {
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.lambda.json
}

resource "aws_lambda_function" "fulfillment" {
  function_name = "${local.name}-fulfillment"
  role          = aws_iam_role.lambda.arn
  package_type  = "Image"
  image_uri     = "123456789012.dkr.ecr.eu-north-1.amazonaws.com/acme-fulfillment:latest"
  memory_size   = 512
  timeout       = 15

  environment {
    variables = {
      MANIFEST_BUCKET_NAME = aws_s3_bucket.manifests.id
      DISPATCH_QUEUE_URL   = aws_sqs_queue.dispatch.url
      SHIPMENTS_TABLE_NAME = aws_dynamodb_table.shipments.name
    }
  }
}
