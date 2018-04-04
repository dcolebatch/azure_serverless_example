# In this example, you will see the following resources created:
#
#  1. A resource group
#  2. Storage Account for the Blob store (HTTP Object store)
#  3. CDN for custom domain name
#  4. DNS Zone and A record
#  5. Azure Container Instance

# But first, configure the Azure Provider and see here to authenticate:
# https://www.terraform.io/docs/providers/azurerm/authenticating_via_azure_cli.html
provider "azurerm" { 
  version = "~> 1.3"
}

# Configure the Cloudflare provider
variable CLOUDFLARE_EMAIL {}
variable CLOUDFLARE_TOKEN {}

provider "cloudflare" {
  email = "${var.CLOUDFLARE_EMAIL}"
  token = "${var.CLOUDFLARE_TOKEN}"
}

#######################################################################
### 1. Resource Group:

# The basis of anything in Azure: We need a Resource Group
resource "azurerm_resource_group" "serverless" {
  name     = "serverless-example"
  location = "West US"

  tags {
    environment = "Serverless Example"
  }
}


#######################################################################
### 2. Storage Account:

# You'll store your pre-compiled JS, HTML and CSS in a Blob Store.
# Blob store is provided by a 'Storage Account'
resource "azurerm_storage_account" "frontend" {
  name                 = "frontendassets"
  resource_group_name = "${azurerm_resource_group.serverless.name}"
  location            = "${azurerm_resource_group.serverless.location}"
  account_tier        = "Standard"

  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "frontend" {
  name                  = "$root"
  resource_group_name   = "${azurerm_resource_group.serverless.name}"
  storage_account_name  = "${azurerm_storage_account.frontend.name}"
  container_access_type = "blob"
}

resource "azurerm_storage_blob" "index" {
  name = "index.html"

  resource_group_name    = "${azurerm_resource_group.serverless.name}"
  storage_account_name   = "${azurerm_storage_account.frontend.name}"
  storage_container_name = "${azurerm_storage_container.frontend.name}"
  type = "block"
  source = "${path.cwd}/../frontend/index.html"
}
output "index" {
  value = "${azurerm_storage_blob.index.url}"
}

resource "azurerm_storage_blob" "css" {
  name = "main.css"

  resource_group_name    = "${azurerm_resource_group.serverless.name}"
  storage_account_name   = "${azurerm_storage_account.frontend.name}"
  storage_container_name = "${azurerm_storage_container.frontend.name}"
  type = "block"
  source = "${path.cwd}/../frontend/main.css"
}
output "css" {
  value = "${azurerm_storage_blob.css.url}"
}


#######################################################################
### 3. CDN:

# We need to use a Content Delivery Network (CDN) to map a custom domain
# to the Blob store contents. Specifically, we must use the 
# Premium (Verizon) CDN.

# No need, CloudFlare will provide our CDN with just the below DNS
# config

#######################################################################
### 4. DNS:
# Since we want to make use of a free CDN and SSL termination service,
# head over to CloudFlare.com, create your domain, and use the below to 
# configure it.  
resource "cloudflare_record" "cfapi" {
  domain  = "serverlessexample.ga"
  name    = "api"
  value   = "${azurerm_container_group.aci-api.ip_address}"
  type    = "A"
  # Enabling CDN is as easy as:
  proxied = true
  # ttl of 1 is "Automatic" in CloudFlare.  When using CDN, we want this:
  ttl     = 1
}

resource "cloudflare_record" "cfazure" {
  domain  = "serverlessexample.ga"
  name    = "azure"
  value   = "frontendassets.blob.core.windows.net"
  type    = "CNAME"
  ttl     = 300
}

# If you need to use the "Indirect CNAME Verification" method, you'll
# want something like this:
#
#  resource "cloudflare_record" "cfazure_verify" {
#   domain  = "serverlessexample.ga"
#   name    = "asverify.azure"
#   value   = "asverify.frontendassets.blob.core.windows.net"
#   type    = "CNAME"
#   ttl     = 300
# }

#######################################################################
### 5. Azure Container Instance:
resource "random_id" "server" {
  keepers = {
    azi_id = 1
  }

  byte_length = 8
}

resource "azurerm_storage_account" "aci-sa" {
  name                = "acisaexample"
  resource_group_name = "${azurerm_resource_group.serverless.name}"
  location            = "${azurerm_resource_group.serverless.location}"
  account_tier        = "Standard"

  account_replication_type = "LRS"
}

resource "azurerm_storage_share" "aci-share" {
  name = "aci-test-share"

  resource_group_name  = "${azurerm_resource_group.serverless.name}"
  storage_account_name = "${azurerm_storage_account.aci-sa.name}"

  quota = 50
}

resource "azurerm_container_group" "aci-api" {
  name                = "aci-api"
  location            = "${azurerm_resource_group.serverless.location}"
  resource_group_name = "${azurerm_resource_group.serverless.name}"
  ip_address_type     = "public"
  os_type             = "linux"

  container {
    name   = "meow"
    image  = "dcolebatch/random-cats"
    cpu    ="0.5"
    memory =  "0.5"
    port   = "80"

    environment_variables {
      "NODE_ENV" = "production"
    }

    volume {
      name       = "logs"
      mount_path = "/aci/logs"
      read_only  = false
      share_name = "${azurerm_storage_share.aci-share.name}"

      storage_account_name  = "${azurerm_storage_account.aci-sa.name}"
      storage_account_key   = "${azurerm_storage_account.aci-sa.primary_access_key}"
    }
  }

  tags {
    environment = "Serverless Example"
  }
}

output "frontend_endpoint" {
  value = "azure.serverlessexample.ga => ${cloudflare_record.cfazure.value}"
}
output "api_endpoint" {
  value = "api.serverlessexample.ga => ${azurerm_container_group.aci-api.ip_address}"
}
