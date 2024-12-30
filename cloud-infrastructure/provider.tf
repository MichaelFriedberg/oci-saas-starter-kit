terraform {
  required_version = ">= 1.0"
  required_providers {
    oci = {
      source  = "oracle/oci"
    }
    hcp = {
      source = "hashicorp/hcp"
      version = "0.91.0"
    }
  }
}

provider "oci" {
  tenancy_ocid     = var.tenancy_ocid
  user_ocid        = var.user_ocid
  fingerprint      = var.fingerprint
  private_key      = base64decode(data.hcp_vault_secrets_app.test.secrets["private_key"])
  region           = "us-ashburn-1"
}

# Using a single workspace:
terraform {
  backend "remote" {
    hostname = "app.terraform.io"
    organization = "saas-starter-kit" # Replace with your Terraform Cloud organization
    workspaces {
      prefix = "oci" # Replace with your Terraform Cloud workspace
    }
  }
}


provider "hcp" {
  # Configuration options
}

