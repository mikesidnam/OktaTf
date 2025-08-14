provider "google" {
  project = "your-gcp-project-id"  # Replace with your free tier project ID
  region  = "us-central1"
}

# Compute Engine Instance (free tier eligible)
resource "google_compute_instance" "example_instance" {
  name         = "lab-instance"
  machine_type = "e2-micro"
  zone         = "us-central1-a"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"  # Free tier eligible image
    }
  }

  network_interface {
    network = "default"
    access_config {}  # Assigns ephemeral public IP
  }
}

# Storage Bucket for Cloud Function source
resource "google_storage_bucket" "function_source" {
  name     = "lab-function-source-${random_id.bucket_suffix.hex}"
  location = "US"
  force_destroy = true
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# Upload function code to bucket (assume local zip; in practice, use null_resource or external upload)
resource "google_storage_bucket_object" "function_zip" {
  name   = "function.zip"
  bucket = google_storage_bucket.function_source.name
  source = "function_code.zip"  # Path to your ZIP file (update for new versions)
}

# Cloud Function (free tier eligible for low usage)
resource "google_cloudfunctions_function" "example_function" {
  name        = "lab-function"
  runtime     = "python312"
  available_memory_mb = 128

  source_archive_bucket = google_storage_bucket.function_source.name
  source_archive_object = google_storage_bucket_object.function_zip.name

  trigger_http = true
  entry_point  = "hello_get"  # Adjust based on your code

  # For version control: Update the ZIP and apply to deploy new version
}

# For Okta integration: Workforce Identity Federation Pool (for OIDC/SAML from Okta)
resource "google_iam_workforce_pool" "okta_pool" {
  workforce_pool_id = "okta-pool"
  parent            = "organizations/your-org-id"  # Replace with your org ID
  location          = "global"
  display_name      = "Okta Pool"
  description       = "Federation with Okta"
  disabled          = false
  session_duration  = "3600s"
}

# Provider in the pool (configure with Okta OIDC details)
resource "google_iam_workforce_pool_provider" "okta_provider" {
  workforce_pool_id  = google_iam_workforce_pool.okta_pool.workforce_pool_id
  provider_id        = "okta-provider"
  location           = "global"
  display_name       = "Okta Provider"
  description        = "Okta OIDC Provider"
  disabled           = false

  oidc {
    issuer_uri        = "https://your-okta-domain.okta.com"  # Replace with Okta issuer
    client_id         = "your-okta-client-id"  # From Okta OIDC app
    client_secret {
      value {
        plain_text = "your-okta-client-secret"
      }
    }
    web_sso {
      response_type = "CODE"
      assertion_claims_behavior = "ONLY_ID_TOKEN_CLAIMS"
    }
  }

  attribute_mapping = {
    "google.subject" = "assertion.sub"
    # Map Okta groups: "google.groups" = "assertion.groups"
  }
}

# Example IAM binding to grant access based on Okta attributes (e.g., groups)
resource "google_project_iam_member" "okta_access" {
  project = "your-gcp-project-id"
  role    = "roles/viewer"  # Example role; manage via Okta groups
  member  = "principalSet://iam.googleapis.com/${google_iam_workforce_pool.okta_pool.name}/attribute.okta_group/example-group"  # Map to Okta group
}
# Node Exporter for Compute Instance
resource "null_resource" "install_node_exporter_gcp" {
  depends_on = [google_compute_instance.example_instance]

  provisioner "remote-exec" {
    inline = [
      "sudo apt update -y",
      "sudo apt install -y wget",
      "wget https://github.com/prometheus/node_exporter/releases/download/v1.8.2/node_exporter-1.8.2.linux-amd64.tar.gz",
      "tar xvfz node_exporter-1.8.2.linux-amd64.tar.gz",
      "sudo mv node_exporter-1.8.2.linux-amd64/node_exporter /usr/local/bin/",
      "sudo nohup /usr/local/bin/node_exporter &"
    ]

    connection {
      type        = "ssh"
      user        = "your-user"
      private_key = file("your_key.pem")
      host        = google_compute_instance.example_instance.network_interface[0].access_config[0].nat_ip
    }
  }
}

# Stackdriver Exporter for GCP metrics (e.g., Cloud Functions)
resource "null_resource" "install_stackdriver_exporter" {
  # Similar: Install and run prometheus-community/stackdriver_exporter
}