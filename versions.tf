
terraform {
  required_version = ">= 0.13"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
    random = {
      source = "hashicorp/random"
    }
  }
}

provider "google" {
  region = local.region
}