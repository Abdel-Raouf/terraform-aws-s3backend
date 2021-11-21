# Use this data source to get the access to the effective Account ID, User ID, and ARN in which Terraform is authorized.
# which means we can get all the data of our own account that we use to deploy to aws.
data "aws_caller_identity" "current" {}

# If no principle ARNs are specified, use the current account.
locals {
  principal_arns = var.principal_arns != null ? var.principal_arns : [data.aws_caller_identity.current.arn]
}

# Here we specifiy what action we will allow or deny for the aws user account we get in our "principle".
# assume_role_policy --> It acts as the trust relationship that we give to the role.
resource "aws_iam_role" "iam_role" {
  name = "${local.namespace}-tf-assume-role"

  assume_role_policy = <<-EOF
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Action": "sts:AssumeRole",
                "Principal": {
                    "AWS": ${jsonencode(local.principal_arns)}
                },
                "Effect": "Allow"
            }
        ]
    }
    EOF

  tags = {
    ResourceGroup = local.namespace
  }
}

# least-privileged policy to attach to the role.
# This data source generates an IAM policy document in JSON format, instead of writing it 
# by hand or make any error related to json syntax or formating.
data "aws_iam_policy_document" "policy_doc" {
  statement {
    actions = [
      "s3:ListBucket",
    ]
    resources = [
      aws_s3_bucket.s3_bucket.arn
    ]
  }

  # give this actions for every object inside our s3 bucket.
  statement {
    actions = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = [
      "${aws_s3_bucket.s3_bucket.arn}/*",
    ]
  }

  statement {
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:DeleteItem"
    ]
    resources = [aws_dynamodb_table.dynamodb_table.arn]
  }

}

# we pass "path" here (optional arg), to be able to match organizational folder structure if needed as 
# /division_abc/subdivision_xyz/product_1234/engineering/
resource "aws_iam_policy" "iam_policy" {
  name   = "${local.namespace}-tf-policy"
  path   = "/"
  policy = data.aws_iam_policy_document.policy_doc.json
}

resource "aws_iam_role_policy_attachment" "policy_attach" {
  role       = aws_iam_role.iam_role.name
  policy_arn = aws_iam_policy.iam_policy.arn
}
