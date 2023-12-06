resource "random_string" "append" {
    lower = true
    upper = false
    numeric = true
    special = false
    length = 5
}


resource "aws_kms_key" "secret" {
  description = "Used for Priama Cloud Agent Deployment Workflow"
  enable_key_rotation = true
}

resource "aws_secretsmanager_secret" "pcc_username" {
  name        = "pcc_username_${random_string.append.result}"
  description = "Prisma Cloud Access Key for Agent Installation"
  kms_key_id  = aws_kms_key.secret.id
}

resource "aws_secretsmanager_secret_version" "pcc_username" {
  secret_id     = aws_secretsmanager_secret.pcc_username.id
  secret_string = var.pcc_username
}

resource "aws_secretsmanager_secret" "pcc_password" {
  name        = "pcc_password_${random_string.append.result}"
  description = "Prisma Cloud Secret Access Key for Agent Installation"
  kms_key_id  = aws_kms_key.secret.id
}

resource "aws_secretsmanager_secret_version" "pcc_password" {
  secret_id     = aws_secretsmanager_secret.pcc_password.id
  secret_string = var.pcc_password
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {

      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "test_role" {
  name               = "pcc_agent_installation_role"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_instance_profile" "test_profile" {
  name = "test_profile"
  role = aws_iam_role.test_role.name
}

resource "aws_iam_role_policy" "test_policy" {
  name = "test_policy"
  role = aws_iam_role.test_role.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "secretsmanager:GetSecretValue",
        "kms:*"        
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_instance" "registry_scanner" {
  # checkov:skip=CKV_AWS_135: The requested configuration is currently not supported.

  instance_type = "t2.micro"
  ami           = "ami-0694d931cee176e7d" ## TODO: Setup Dynamic AMI Discovery

  iam_instance_profile = aws_iam_instance_profile.test_profile.id

  monitoring = true
  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    volume_size = 10 # GB
  }

  key_name = var.ec2_key_name
  
  user_data = <<-EOL
    #!/bin/bash -xe

    hostnamectl set-hostname pcc-on-demand-scanner

    apt update && apt install -y awscli docker.io jq

    PCC_USERNAME=$(aws secretsmanager get-secret-value --secret-id ${aws_secretsmanager_secret.pcc_username.id} --region eu-west-1 | jq .SecretString -r)
    PCC_PASSWORD=$(aws secretsmanager get-secret-value --secret-id ${aws_secretsmanager_secret.pcc_password.id} --region eu-west-1 | jq .SecretString -r)
    PCC_URL=$(echo "${var.pcc_url}" | sed -e 's@^.*://@@' -e 's/[/:].*$//')

    json_auth_data="$(printf '{ "username": "%s", "password": "%s" }' "$PCC_USERNAME" "$PCC_PASSWORD")"
    token=$(curl -sSLk -d "$json_auth_data" -H 'content-type: application/json' "${var.pcc_url}/api/v1/authenticate" | jq .token -r)
    curl -sSLk -H "authorization: Bearer $token" -X POST "${var.pcc_url}/api/v1/scripts/defender.sh" | bash -s -- -c "$PCC_URL" -d "none"

    curl -k \
      -H "authorization: Bearer $token" \
      -H 'Content-Type: application/json'\
      -X POST \
      -d '{"onDemandScan":true,"tag":{"registry" :"${var.registry_to_scan}","repo":"${var.repository_to_scan}","digest":"","tag":"${var.tag_to_scan}"}}' \
      "${var.pcc_url}/api/v1/registry/scan"

    EOL

  tags = {
    "Name" = "pcc-on-demand-scanner"
  }

}