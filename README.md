# Sample Serverless app on Azure

This repo contains example terraform configuration for a serverless
style application on Azure.  This deployment makes use of:

1. Azure DNS
2. Azure CDN
3. Azure Blob Storage
4. Azure Container Instances

See `setup/main.tf` for details.

## Synopsis
```
cd setup
az login
az account set --subscription="TARGET SUBSCRIPTION ID"
terraform plan
terraform apply
```

---
Created by [Tidal Migrations](https://tidalmigrations.com)

