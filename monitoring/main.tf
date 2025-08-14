provider "aws" {
  region = "us-west-2"
}

# Prometheus Server on EC2 t3.micro (free tier)
resource "aws_instance" "prometheus_server" {
  ami           = "ami-0abcdef1234567890"  # Amazon Linux 2 AMI (free tier eligible)
  instance_type = "t3.micro"
  tags = {
    Name = "lab-prometheus"
  }

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              amazon-linux-extras install docker -y
              service docker start
              usermod -a -G docker ec2-user
              docker run -d -p 9090:9090 \
                -v /etc/prometheus:/etc/prometheus \
                prom/prometheus --config.file=/etc/prometheus/prometheus.yml
              EOF

  # Security group to allow Prometheus access (port 9090) and scraping
  vpc_security_group_ids = [aws_security_group.prometheus_sg.id]
}

resource "aws_security_group" "prometheus_sg" {
  name        = "prometheus_sg"
  description = "Allow Prometheus traffic"

  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Restrict to your IP for security
  }

  ingress {
    from_port   = 9100  # For node_exporter
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Example prometheus.yml config (uploaded via null_resource or manage separately in Git)
resource "null_resource" "prometheus_config" {
  provisioner "local-exec" {
    command = "echo '${local.prometheus_yml}' > prometheus.yml"
  }

  # Upload to EC2 (use scp or configure in user_data for prod)
  provisioner "file" {
    source      = "prometheus.yml"
    destination = "/etc/prometheus/prometheus.yml"
    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("your_key.pem")  # Replace
      host        = aws_instance.prometheus_server.public_ip
    }
  }
}

locals {
  prometheus_yml = <<-EOT
    global:
      scrape_interval: 15s

    scrape_configs:
      - job_name: 'aws-ec2'
        static_configs:
          - targets: ['${aws_instance.example_ec2.private_ip}:9100']  # Scrape node_exporter on your EC2

      - job_name: 'aws-lambda'
        metrics_path: '/metrics'
        static_configs:
          - targets: ['localhost:9101']  # Assuming cloudwatch_exporter on same host or separate

      - job_name: 'gcp-instance'
        static_configs:
          - targets: ['${google_compute_instance.example_instance.network_interface[0].access_config[0].nat_ip}:9100']

      - job_name: 'okta'
        metrics_path: '/metrics'
        static_configs:
          - targets: ['localhost:9110']  # Custom Okta exporter
    EOT
}

# Optional: Grafana for visualization (deploy similarly on same EC2)
resource "aws_instance" "grafana" {  # Or co-locate with Prometheus
  # Similar to prometheus_server, docker run grafana/grafana, port 3000
  # Configure Okta OAuth in Grafana for access control via groups
}