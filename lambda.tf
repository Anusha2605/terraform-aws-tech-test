#Defining archive provider
provider "archive" {}

#Archive the python 3 file used in the lambda function in .zip format
data "archive_file" "zip" {
  type        = "zip"
  source_file = "instance_status.py"
  output_path = "instance_status.zip"
}

#Create an IAM role for lambda function
resource "aws_iam_role" "ec2_dynamodb_lambda" {
  name = "ec2_dynamodb_lambda"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

#Create policy to allow lambda to get instance status from EC2 and write data to dynamodb
resource "aws_iam_policy" "policy_one" {
  name = "policy-for-lambda"
  policy = jsonencode(
   {
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:DescribeInstanceStatus"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "dynamodb:PutItem"
            ],
            "Resource": "*"
        }
    ]
    
    }) 
    
}

#Attach the policy to the role 
resource "aws_iam_role_policy_attachment" "policy-role-attach" {
  role       = aws_iam_role.ec2_dynamodb_lambda.name
  policy_arn = aws_iam_policy.policy_one.arn
}

#Create the lambda function
resource "aws_lambda_function" "lambda" {
  function_name = "instance_status"

  filename         = data.archive_file.zip.output_path
  source_code_hash = data.archive_file.zip.output_base64sha256

  role    = aws_iam_role.ec2_dynamodb_lambda.arn
  handler = "instance_status.lambda_handler"
  runtime = "python3.9"

}

#resource "aws_cloudwatch_event_rule" "every_one_hour" {
#  name                = "every-one-hour"
#  description         = "Fires every one hour"
#  schedule_expression = "rate(1 hour)"
#  schedule_expression = "cron(0 0-23 * * *)"
#}
#
#resource "aws_cloudwatch_event_target" "check_foo_every_one_hour" {
#  rule      = aws_cloudwatch_event_rule.every_one_hour.name
#  target_id = "lambda"
#  arn       = aws_lambda_function.lambda.arn
#}
#
#resource "aws_lambda_permission" "allow_cloudwatch_to_call_lambda" {
#  statement_id  = "AllowExecutionFromCloudWatch"
#  action        = "lambda:InvokeFunction"
#  function_name = aws_lambda_function.lambda.function_name
#  principal     = "events.amazonaws.com"
#  source_arn    = aws_cloudwatch_event_rule.every_one_hour.arn
#}

resource "aws_dynamodb_table" "ec2_instance_status" {
  name         = "ec2_instance_status"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "currentdatetime"
  range_key    = "InstanceState"

  attribute {
    name = "currentdatetime"
    type = "S"
  }
  attribute {
    name = "InstanceState"
    type = "S"
  }
  ttl {
    attribute_name = "expirydatetime"
    enabled        = true
  }
}