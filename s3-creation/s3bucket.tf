terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider (Mumbai)
provider "aws" {
  region = "ap-south-1"
}

# 1. S3 Bucket
resource "aws_s3_bucket" "example" {
  bucket = "my-tf-test-bucket-11-09" # Ensure this name is globally unique

  tags = {
    Name        = "My bucket"
    Environment = "testing-purpose"
  }
} # Fixed: Added missing closing brace

# 2. Disable Public Access Block (Required for public websites)
resource "aws_s3_bucket_public_access_block" "example" {
  bucket = aws_s3_bucket.example.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# 3. Enable Static Website Hosting
resource "aws_s3_bucket_website_configuration" "example" {
  bucket = aws_s3_bucket.example.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

# 4. Bucket Policy for Public Read (Only ONE policy)
resource "aws_s3_bucket_policy" "allow_public_read" {
  bucket = aws_s3_bucket.example.id

  # Ensures public access block is removed before applying policy
  depends_on = [aws_s3_bucket_public_access_block.example]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.example.arn}/*"
      }
    ]
  })
}

# 5. Upload index.html
resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.example.id
  key          = "index.html"
  source       = "${path.module}/practice/index.html" # Points to existing file
  content_type = "text/html"                          # Prevents browser auto-downloading
  etag         = filemd5("${path.module}/practice/index.html")
}

# 6. Output the website URL
output "website_endpoint" {
  description = "Website URL"
  value       = "http://${aws_s3_bucket_website_configuration.example.website_endpoint}"
}
