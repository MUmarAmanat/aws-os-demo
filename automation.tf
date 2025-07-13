resource "aws_iam_policy" "opensearch_policy_terraform_resource" {
    name        = "AWSOpenSearchPolicy"
    description = "IAM policy with limited access to OpenSearch Service resources created via terraform"

    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Effect = "Allow"
                Action = [
                    "aoss:CreateCollection",
                    "aoss:ListCollections",
                    "aoss:BatchGetCollection",
                    "aoss:DeleteCollection",
                    "aoss:CreateAccessPolicy",
                    "aoss:ListAccessPolicies",
                    "aoss:UpdateAccessPolicy",
                    "aoss:CreateSecurityPolicy",
                    "aoss:GetSecurityPolicy",
                    "aoss:UpdateSecurityPolicy",
                    "iam:ListUsers",
                    "iam:ListRoles"
                ]
                Resource = "*"
            }
        ]
    })
}


resource "aws_iam_user" "aws_os_demo_user" {
  name = "aws-os-demo-user"
}

resource "aws_iam_user_policy_attachment" "aws_os_demo_user_policy_attachment" {
  user       = aws_iam_user.aws_os_demo_user.name
  policy_arn = aws_iam_policy.opensearch_policy_terraform_resource.arn
}

resource "aws_iam_access_key" "aws_os_demo_user_access_key" {
  user = aws_iam_user.aws_os_demo_user.name
}


output "access_key_id" {
  value     = aws_iam_access_key.aws_os_demo_user_access_key.id
  sensitive = true
}

output "secret_access_key" {
  value     = aws_iam_access_key.aws_os_demo_user_access_key.secret
  sensitive = true
}

resource "local_file" "aws_credentials" {
  content = <<EOF
AWS_ACCESS_KEY_ID=${aws_iam_access_key.aws_os_demo_user_access_key.id}
AWS_SECRET_ACCESS_KEY=${aws_iam_access_key.aws_os_demo_user_access_key.secret}
EOF

  filename = "${path.module}/aws_os_demo_user_credentials.txt"
}

resource "aws_opensearchserverless_security_policy" "encryption_policy" {
    name        = "aws-os-demo-collection-enc-plcy"
    type        = "encryption"
    description = "Encryption policy for aws-os-demo-collection"

    policy = jsonencode({
        Rules = [
           {
            ResourceType = "collection",
            Resource     = ["collection/aws-os-demo-collection"]
          }
        ]
        AWSOwnedKey = true
    })
}

resource "aws_opensearchserverless_security_policy" "network_policy" {
  name        = "aws-os-demo-collection-net-plcy"
  type        = "network"
  description = "Network policy for aws-os-demo-collection"

  policy = jsonencode([
    {
      Rules = [
        {
          ResourceType = "collection",
          Resource     = ["collection/aws-os-demo-collection"]
        }
      ],
      AllowFromPublic = true
    }
  ])
}

data "aws_caller_identity" "current" {}

resource "aws_opensearchserverless_access_policy" "data_access_policy" {
  name        = "aws-os-demo-collection-data-plcy"
  type        = "data"
  description = "Data access policy for aws-os-demo-collection"

  policy = jsonencode([
    {
      Rules = [
        {
          ResourceType = "collection",
          Resource     = ["collection/aws-os-demo-collection"],
          Permission   = ["aoss:DescribeCollectionItems"]
        },
        {
          ResourceType = "index",
          Resource     = ["index/aws-os-demo-collection/*"], 
          Permission   = [
            "aoss:DescribeIndex",
            "aoss:ReadDocument",
            "aoss:WriteDocument",
            "aoss:CreateIndex"
          ]
        }
      ],
      Principal = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/aws-os-demo-user"
      ]
    }
  ])
}



resource "aws_opensearchserverless_collection" "aws_os_demo_collection" {
  name = "aws-os-demo-collection"
  type = "VECTORSEARCH"
  depends_on = [
                aws_opensearchserverless_security_policy.encryption_policy,
                aws_opensearchserverless_security_policy.network_policy,
                aws_opensearchserverless_access_policy.data_access_policy
              ]
}


