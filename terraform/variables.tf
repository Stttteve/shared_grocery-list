variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "project" {
  type    = string
  default = "grocery"
}

variable "bucket_name" {
  type    = string
  default = "shared-grocery-lists"
}

variable "lambda_runtime" {
  type    = string
  default = "python3.9"
}

variable "tags" {
  type = map(string)
  default = {
    Project     = "grocery"
    Environment = "dev"
  }
}