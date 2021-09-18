resource "aws_dynamodb_table" "basic_dynamodb_table" {
  name           = "brews"
  billing_mode   = "PROVISIONED"
  read_capacity  = 1
  write_capacity = 1
  hash_key       = "id"
  range_key      = "brew_title"
  attribute {
    name = "id"
    type = "S"
  }

  attribute {
    name = "brew_title"
    type = "S"
  }

  tags = {
    Name        = "dynamodb-table-1"
    Environment = "production"
  }
}
