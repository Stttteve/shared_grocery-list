terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "grocery_lists" {
  bucket = "shared-grocery-lists-${random_id.suffix.hex}"
}

resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_iam_group" "shoppers" {
  name = "Shoppers"
}

resource "aws_iam_group" "viewers" {
  name = "Viewers"
}

# IAM Policy for Shoppers
resource "aws_iam_policy" "shopper_policy" {
  name        = "ShopperPermissions"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect: "Allow",
        Action: [
          "s3:PutObject",
          "s3:GetObject"
        ],
        Resource: "${aws_s3_bucket.grocery_lists.arn}/*"
      },
      {
        Effect: "Deny",
        Action: "*",
        Resource: "*",
        Condition: {
          BoolIfExists: {
            "aws:MultiFactorAuthPresent" = "false"
          }
        }
      }
    ]
  })
}

# IAM Policy for Viewers
resource "aws_iam_policy" "viewer_policy" {
  name        = "ViewerPermissions"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect: "Allow",
        Action: "s3:GetObject",
        Resource: "${aws_s3_bucket.grocery_lists.arn}/*"
      }
    ]
  })
}

# Attach policies to groups
resource "aws_iam_group_policy_attachment" "shopper_attach" {
  group      = aws_iam_group.shoppers.name
  policy_arn = aws_iam_policy.shopper_policy.arn
}

resource "aws_iam_group_policy_attachment" "viewer_attach" {
  group      = aws_iam_group.viewers.name
  policy_arn = aws_iam_policy.viewer_policy.arn
}

# Lambda for group verification
resource "aws_lambda_function" "group_verifier" {
  filename      = "../lambda/verifyGroup.zip"
  function_name = "VerifyUserGroup"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "index.lambda_handler"
  runtime       = "python3.9"
}

resource "aws_iam_role" "lambda_exec" {
  name = "LambdaExecutionRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect: "Allow",
      Principal: { Service: "lambda.amazonaws.com" },
      Action: "sts:AssumeRole"
    }]
  })
}