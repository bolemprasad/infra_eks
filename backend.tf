### create s3 bucket
resource "aws_s3_bucket" "test_bucket" {
    bucket = var.aws_s3_bucket
    
    versioning {
      enabled = true
    }
    tags = var.s3_bucket_tag
    
  
}


#### s3 backend storing state file in remote location

terraform {
  backend "s3" {
    bucket = "9100-246-253-123"
    key = "terraform/terraform.tfstate"
    region = "us-east-1"
    #dynamodb_table = "dynamodb-state-lock"
    encrypt = true

    
  }
}