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
  
  custom_domain {
    name = "azure.serverlessexample.ga"
  }
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
resource "cloudflare_record" "cfazure" {
  domain  = "serverlessexample.ga"
  name    = "azure"
  value   = "frontendassets.blob.core.windows.net"
  type    = "CNAME"
  proxied = true
  ttl     = 1
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
### 5. Azure Function
resource "azurerm_storage_account" "function" {
  name                     = "functionsappexample"
  resource_group_name      = "${azurerm_resource_group.serverless.name}"
  location                 = "${azurerm_resource_group.serverless.location}"
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_app_service_plan" "functions" {
  name                = "azure-functions-example-sp"
  location            = "${azurerm_resource_group.serverless.location}"
  resource_group_name = "${azurerm_resource_group.serverless.name}"
  kind                = "FunctionApp"

  sku {
    tier = "Dynamic"
    size = "Y1"
  }
}

resource "azurerm_function_app" "randomcats" {
  name                      = "randomcats-azure-functions"
  location                  = "${azurerm_resource_group.serverless.location}"
  resource_group_name       = "${azurerm_resource_group.serverless.name}"
  app_service_plan_id       = "${azurerm_app_service_plan.functions.id}"
  storage_connection_string = "${azurerm_storage_account.function.primary_connection_string}"
}


output "frontend_endpoint" {
  value = "azure.serverlessexample.ga => ${cloudflare_record.cfazure.value}"
}
output "function_endpoint" {
  value = "${azurerm_function_app.randomcats.name}.azurewebsites.net"
}

