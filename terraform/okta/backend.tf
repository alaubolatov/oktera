terraform {
  required_providers {
    okta = {
      source  = "okta/okta"
      version = "~> 6.5.0"
    }
  }

  # backend is configured in github workflows via additional arguments to `terraform init`
  # https://developer.hashicorp.com/terraform/language/settings/backends/configuration#partial-configuration
  backend "azurerm" {}
}

# version 3.44.0: https://registry.terraform.io/providers/okta/okta/3.44.0/docs
# configuration is done via env variables, see `.env.example`
provider "okta" {}