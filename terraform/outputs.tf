output "bucket_name" {
  description = "Grocery list S3 bucket"
  value       = aws_s3_bucket.grocery_lists.bucket
}

output "verify_fn_arn" {
  description = "ARN of the user-group verification Lambda"
  value       = aws_lambda_function.group_verifier.arn
}