# Terraform version and plugin versions

terraform {
  required_version = "~> 0.13.0"
  required_providers {
    template = "~> 2.1"
    null     = "~> 2.1"

    ct = {
      source  = "poseidon/ct"
      version = "~> 0.6"
    }

    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 1.20"
    }
  }
}

