# Remote BuildKit Instance for Docker Builds

This repository contains Terraform scripts and GitHub Actions workflow to set up and use a remote BuildKit instance for running Docker builds.

## Overview

The main components of this setup are:

1. `main.tf`: Terraform script to create an EC2 instance with BuildKit installed.
2. `terraform.tfvars`: Variables file for Terraform (you need to populate this).
3. `Dockerfile`: A sample Dockerfile for testing.
4. `buildkit-test.yml`: Example GitHub Actions workflow to use the remote BuildKit instance.

## Quick Start

1. Clone this repository.
2. Configure AWS CLI with your credentials.
3. Populate `terraform.tfvars` with your GitHub organization and repository name:

   ```
   github_org = "your-org-name"
   github_repo = "your-repo-name"
   ```

4. Set the following environment variables:
   - `BUILDKIT_HOST`: The public IP address of your EC2 instance (you'll get this after applying Terraform).
   - `AWS_ACCOUNT_ID`: Your AWS account ID.

5. Run Terraform:

   ```
   terraform init
   terraform plan
   terraform apply
   ```

6. After `terraform apply` is successful, you'll get the public IP of your BuildKit instance. Use this to set the `BUILDKIT_HOST` environment variable.

## Terraform Configuration Details

The `main.tf` file sets up the following resources:

- EC2 instance with BuildKit installed
  - Instance type: c5a.4xlarge (16 vCPUs, 32 GiB Memory)
  - AMI: Amazon Linux 2 (ami-05c3dc660cb6907f0 in us-east-2)
  - Root volume: 100 GB gp3 EBS volume
  - User data script installs Docker, BuildKit, and sets up a systemd service for BuildKit
  - BuildKit is configured to listen on port 9999
- Security group for the EC2 instance
- IAM role and instance profile for the EC2 instance
- OIDC provider for GitHub Actions
- IAM role for GitHub Actions with necessary permissions

The EC2 instance is configured with user data to install and set up BuildKit. It exposes BuildKit on port 9999 by default.

## GitHub Actions Workflow

The included workflow file (`buildkit-test.yml`) demonstrates how to use the remote BuildKit instance in your CI/CD pipeline. It sets up the AWS credentials, configures BuildKit to use the remote instance, and runs a Docker build.

## Important Security Note

⚠️ **Warning**: The current setup does not exclusively whitelist GitHub Actions runners' IPs. For production use, it's strongly recommended to restrict the security group ingress rules to only allow traffic from [GitHub Actions IP ranges](https://api.github.com/meta)

## Customization

- You can change the BuildKit port (default: 9999) in the EC2 instance user data script and the GitHub Actions workflow file.
- Adjust the EC2 instance type and region in `main.tf` as needed.
- Modify the IAM permissions in `main.tf` if you need additional AWS services access.

## Contributing

Contributions to improve this setup are welcome! Please submit a pull request or open an issue to discuss proposed changes.

## License

[MIT License](LICENSE)
