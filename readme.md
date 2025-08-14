# Okta Lab Project

This project manages AWS, GCP, and Okta resources using Terraform in the free tier.

## Setup
1. Install Terraform.
2. Set environment variables (e.g., OKTA_API_TOKEN, AWS credentials, GCP project).
3. In each folder: terraform init, terraform plan, terraform apply.

## Integration
- Okta manages identity for AWS (SAML) and GCP (OIDC).
- Use Okta groups for access control.

