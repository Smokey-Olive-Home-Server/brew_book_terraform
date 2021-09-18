# resource "aws_s3_bucket" "home_server_lambda_zips" {
#   bucket = "home-server-lambda-zips"
#   acl    = "private"

#   tags = {
#     Name = "Home Server lambda Zips"
#   }
# }

resource "aws_s3_bucket" "home_server_statics" {
  bucket = "home-server-statics"
  acl    = "public-read"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "PublicRead",
        "Effect" : "Allow",
        "Principal" : "*",
        "Action" : ["s3:GetObject", "s3:GetObjectVersion"],
        "Resource" : ["arn:aws:s3:::home-server-statics/*"]
      }
    ]
  })

  website {
    index_document = "index.html"
    error_document = "error.html"
  }
}
