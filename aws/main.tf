provider "aws" {
  region = "us-west-2"  # Free tier eligible region
}

# EC2 Instance (free tier eligible)
resource "aws_instance" "example_ec2" {
  ami           = "ami-0abcdef1234567890"  # Replace with a free tier eligible AMI ID, e.g., Amazon Linux 2 in your region
  instance_type = "t3.micro"
  tags = {
    Name = "lab-ec2"
  }
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "lab_lambda_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Effect = "Allow"
      },
    ]
  })
}

# Attach basic execution policy to Lambda role
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambda Function (free tier eligible for low usage)
resource "aws_lambda_function" "example_lambda" {
  filename      = "lambda_code.zip"  # Path to your ZIP file containing Lambda code (update this for new versions)
  function_name = "lab_lambda"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.handler"  # Adjust based on your code (e.g., for Node.js)
  runtime       = "python3.12"     # Free tier eligible runtime
  publish       = true             # Enables versioning on updates

  # For version control: Update the ZIP file and apply to create a new version
}

# Optional: Lambda Alias for version management
resource "aws_lambda_alias" "example_alias" {
  name             = "prod"
  function_name    = aws_lambda_function.example_lambda.function_name
  function_version = "$LATEST"  # Point to specific versions as needed
}

# For Okta integration: SAML Provider (download metadata from Okta app and place in okta_metadata.xml)
resource "aws_iam_saml_provider" "okta" {
  name                   = "Okta"
  saml_metadata_document = file("okta_metadata.xml")  # Replace with path to Okta SAML metadata
}

# Example IAM Role assumable via Okta SAML (mapped to Okta groups in Okta console/app config)
resource "aws_iam_role" "okta_assumed_role" {
  name = "okta_assumed_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_saml_provider.okta.arn
        }
        Action = "sts:AssumeRoleWithSAML"
        Condition = {
          StringEquals = {
            "SAML:aud" = "https://signin.aws.amazon.com/saml"
          }
        }
      },
    ]
  })
}

# Attach a policy to the role (e.g., read-only access; manage access via Okta group assignments)
resource "aws_iam_role_policy_attachment" "okta_role_policy" {
  role       = aws_iam_role.okta_assumed_role.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# Node Exporter for EC2 host metrics (CPU, memory, etc.)
resource "null_resource" "install_node_exporter" {
  depends_on = [aws_instance.example_ec2]

  provisioner "remote-exec" {
    inline = [
      "sudo yum install -y wget",
      "wget https://github.com/prometheus/node_exporter/releases/download/v1.8.2/node_exporter-1.8.2.linux-amd64.tar.gz",
      "tar xvfz node_exporter-1.8.2.linux-amd64.tar.gz",
      "sudo mv node_exporter-1.8.2.linux-amd64/node_exporter /usr/local/bin/",
      "sudo nohup /usr/local/bin/node_exporter &"
    ]

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("your_key.pem")
      host        = aws_instance.example_ec2.public_ip
    }
  }
}

# CloudWatch Exporter for AWS metrics (e.g., Lambda)
resource "null_resource" "install_cloudwatch_exporter" {
  # Similar remote-exec to install and run java -jar cloudwatch_exporter.jar -f config.yml
  # Config.yml: Scrape Lambda metrics from CloudWatch
}