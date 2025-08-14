provider "okta" {
  org_name  = "your-org"  # e.g., dev-123456
  base_url  = "okta.com"
  api_token = var.okta_api_token
}

# User Management
resource "okta_user" "example_user" {
  first_name = "Lab"
  last_name  = "User"
  login      = "lab.user@example.com"
  email      = "lab.user@example.com"
}

# Group Management
resource "okta_group" "example_group" {
  name        = "LabGroup"
  description = "Group for lab access"
}

# Group Rule Management (assign users to groups based on rules)
resource "okta_group_rule" "example_rule" {
  name              = "LabRule"
  status            = "ACTIVE"
  group_assignments = [okta_group.example_group.id]
  expression_type   = "urn:okta:expression:1.0"
  expression_value  = "String.stringContains(user.email,\"@example.com\")"
}

# Example SCIM App with Provisioning/Deprovisioning
resource "okta_app_basic" "scim_app" {
  label   = "Lab SCIM App"
  status  = "ACTIVE"
  features = ["PROVISIONING"]  # Enables provisioning/deprovisioning

  # Provisioning connection (replace with your SCIM endpoint details)
  provisioning_connection {
    auth_scheme = "HEADER"
    auth_params = {
      key   = "Authorization"
      value = "Bearer your-scim-token"  # Replace with actual token
    }
    url = "https://your-scim-app.com/scim/v2"  # Replace with SCIM base URL
  }
}

# Assign group to SCIM app for provisioning
resource "okta_app_group_assignment" "scim_group_assignment" {
  app_id   = okta_app_basic.scim_app.id
  group_id = okta_group.example_group.id
}

# Assign user to SCIM app (provisions user)
resource "okta_app_user" "scim_user_assignment" {
  app_id   = okta_app_basic.scim_app.id
  user_id  = okta_user.example_user.id
  username = okta_user.example_user.login
}

# AWS App for Federation (SAML) with Group-Based Access
resource "okta_app_saml" "aws_app" {
  label                    = "AWS Lab"
  preconfigured_app        = "amazon_aws"
  app_settings_json        = jsonencode({ "awsEnvironmentId": "your-aws-account-id" })  # Replace
  features                 = ["SAML", "PROVISIONING"]  # Enables provisioning where supported
  status                   = "ACTIVE"
}

# Assign group to AWS app (maps to AWS roles; configure role mappings in Okta console)
resource "okta_app_group_assignment" "aws_group_assignment" {
  app_id   = okta_app_saml.aws_app.id
  group_id = okta_group.example_group.id
}

# GCP App for Federation (OIDC example; use for console access)
resource "okta_app_oauth" "gcp_app" {
  label                      = "GCP Lab"
  type                       = "web"
  grant_types                = ["authorization_code", "implicit"]
  redirect_uris              = ["https://console.cloud.google.com/oidc"]
  response_types             = ["code", "id_token"]
  issuer_mode                = "ORG_URL"
  client_uri                 = "https://cloud.google.com"
  login_uri                  = "https://console.cloud.google.com"
  post_logout_redirect_uris  = ["https://console.cloud.google.com"]
  status                     = "ACTIVE"
}

# Assign group to GCP app (manages access via groups)
resource "okta_app_group_assignment" "gcp_group_assignment" {
  app_id   = okta_app_oauth.gcp_app.id
  group_id = okta_group.example_group.id
}

# --- Additional Implementations ---

# Policies and Rules (Example: Sign-on Policy and Rule)
resource "okta_policy_signon" "example_signon_policy" {
  name        = "LabSignOnPolicy"
  status      = "ACTIVE"
  description = "Sign-on policy for lab users"
}

resource "okta_policy_rule_signon" "example_signon_rule" {
  policyid      = okta_policy_signon.example_signon_policy.id
  name          = "LabSignOnRule"
  status        = "ACTIVE"
  access        = "ALLOW"
  authtype      = "ANY"
  # Add conditions, e.g., based on groups or locations
}

# Applications (Advanced Features: Example Bookmark App and Access Policy Assignment)
resource "okta_app_bookmark" "example_bookmark_app" {
  label = "Lab Bookmark App"
  url   = "https://example.com"
}

resource "okta_app_access_policy_assignment" "example_access_assignment" {
  app_id     = okta_app_bookmark.example_bookmark_app.id
  policy_id  = okta_policy_signon.example_signon_policy.id
}

# Identity Providers (IdPs: Example Google Social IdP)
resource "okta_idp_social" "google_idp" {
  type          = "GOOGLE"
  name          = "Google IdP"
  protocol_type = "OIDC"
  scopes        = ["openid", "profile", "email"]
  client_id     = "your-google-client-id"
  client_secret = "your-google-client-secret"
}

# Authorization Servers (Example: Custom Auth Server with Policy and Claim)
resource "okta_auth_server" "example_auth_server" {
  name        = "LabAuthServer"
  audiences   = ["api://example"]
  description = "Custom auth server for APIs"
}

resource "okta_auth_server_policy" "example_auth_policy" {
  auth_server_id = okta_auth_server.example_auth_server.id
  name           = "LabAuthPolicy"
  description    = "Policy for token issuance"
  priority       = 1
}

resource "okta_auth_server_claim" "example_claim" {
  auth_server_id = okta_auth_server.example_auth_server.id
  name           = "custom_claim"
  value_type     = "EXPRESSION"
  value          = "user.email"
  claim_type     = "IDENTITY"
}

# Security and Network Features (Example: Network Zone and Behavior)
resource "okta_network_zone" "example_zone" {
  name     = "LabTrustedZone"
  type     = "IP"
  gateways = ["192.168.0.0/24"]  # Example IP range
  status   = "ACTIVE"
}

resource "okta_behavior" "example_behavior" {
  name         = "LabAnomalyBehavior"
  type         = "ANOMALY"
  settings_json = jsonencode({
    "granularity" = "WEEK"
    "confidence"  = "MEDIUM"
  })
}

# Branding and Customization (Example: Email Template and Theme)
resource "okta_email_template" "example_email_template" {
  name = "LabEmailTemplate"
}

resource "okta_email_customization" "example_customization" {
  brand_id     = "default"  # Or use okta_brand resource ID
  template_name = okta_email_template.example_email_template.name
  language     = "en"
  is_default   = true
  subject      = "Welcome to Lab"
  body         = "Hello {{user.firstName}}, welcome!"
}

resource "okta_theme" "example_theme" {
  brand_id = "default"
  logo     = "/path/to/logo.png"  # Base64 or file path
}

# Admin Roles and Permissions (Example: Custom Admin Role)
resource "okta_admin_role_custom" "example_custom_role" {
  label       = "LabCustomAdmin"
  description = "Custom role for lab admins"
  permissions = ["okta.users.read", "okta.groups.manage"]
}

# Other Resources (Example: Inline Hook and Custom User Schema)
resource "okta_inline_hook" "example_inline_hook" {
  name    = "LabInlineHook"
  version = "1.0.1"
  type    = "com.okta.user.pre-registration"
  channel = {
    type    = "HTTP"
    version = "1.0.0"
    uri     = "https://your-hook-endpoint.com"
  }
}

resource "okta_user_schema_property" "example_schema_property" {
  index       = "customField"
  title       = "Custom Field"
  type        = "string"
  description = "A custom user attribute"
  master      = "OKTA"
  scope       = "SELF"
}
# Custom Okta Exporter (deploy on Prometheus EC2 or separate)
resource "null_resource" "okta_exporter" {
  provisioner "remote-exec" {
    inline = [
      "go install github.com/Doist/okta-exporter@latest",  # Or use a pre-built binary; assumes Go installed
      "nohup okta-exporter -token ${var.okta_api_token} &"  # Exposes /metrics with Okta stats
    ]

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("your_key.pem")
      host        = aws_instance.prometheus_server.public_ip  # From monitoring folder; use depends_on
    }
  }
}