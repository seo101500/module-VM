module "resource_group" {
  source   = "./modules/resource_group"
  name     = "rg-aks"
  location = "Korea Central"
}

module "vnet" {
  source              = "./modules/vnet"
  name                = "kc-vnet"
  address_space       = ["10.1.0.0/16"]
  location            = "East US" 
  resource_group_name = azurerm_resource_group.example.name
}


module "subnet" {
  source              = "./modules/subnet"
  aks_subnet_name     = "aks-subnet"
  resource_group_name = "your_resource_group_name"
  vnet_name           = "your_vnet_name"
  aks_subnet_prefixes = ["10.1.2.0/24"]

  appgw_subnet_name   = "kc-agw-svnet"
  appgw_subnet_prefixes = ["10.1.1.0/24"]
  dns_prefix          = "dns"
}


module "aks" {
  source              = "./modules/aks"
  aks_name            = "aks-cluster"
  location            = module.resource_group.location
  resource_group_name = module.resource_group.name
  dns_prefix          = module.network.dns_prefix
  node_count          = 1
  vm_size             = "Standard_DS2_v2"
  enable_node_public_ip = true
  vnet_subnet_id      = module.network.subnet_aks_id
  admin_username      = "adminuser"
  ssh_key_data        = jsondecode(azapi_resource_action.ssh_public_key_gen.output).publicKey
  gateway_id          = module.app_gateway.gateway_id
}

module "appgw_public_ip" {
  source              = "./modules/appgw_public_ip"
  name                = "appgw-ip"
  location            = module.resource_group.location
  resource_group_name = module.resource_group.name
}

module "app_gateway" {
  source = "./modules/app_gateway"
  
  name                           = "aks-appgw"
  location                       = azurerm_resource_group.rg.location
  resource_group_name            = azurerm_resource_group.rg.name
  sku_name                       = "Standard_v2"
  sku_tier                       = "Standard_v2"
  min_capacity                   = 2
  max_capacity                   = 5
  gateway_ip_configuration_name  = "appgw-ip-configuration"
  subnet_id                      = azurerm_subnet.appgw_subnet.id
  frontend_port_name             = "appgw-http-port"
  frontend_port                  = 80
  frontend_ip_configuration_name = "appgw-frontend-ip-configuration"
  public_ip_address_id           = azurerm_public_ip.appgw_public_ip.id
  backend_address_pool_name      = "yourBackendPoolName"
  backend_http_settings_name     = "yourHttpSettingsName"
  backend_http_settings_port     = 80
  request_timeout                = 60
  http_listener_name             = "yourListenerName"
  request_routing_rule_name      = "yourRoutingRuleName"
  priority                       = 1
}

module "acr" {
  source                      = "./modules/acr"
  acr_name                    = "MetaAcr"
  resource_group_name         = azurerm_resource_group.rg.name
  location                    = azurerm_resource_group.rg.location
  sku                         = "Basic"
  admin_enabled               = false
  aks_kubelet_identity_object_id = module.aks.kubelet_identity_object_id
  aks_cluster_name            = "aks-cluster"
  aks_resource_group_name     = "rg-aks"
}

module "vmss_network" {
  source              = "./modules/vmss_network"
  vnet_name           = "kc-vnet"
  subnet_name         = "aks-subnet"
  resource_group_name = "your-resource-group-name"
}

module "argocd" {
  source = "./modules/argocd"

  argocd_namespace    = "argocd"
  server_service_type = "NodePort"
}

module "grafana" {
  source = "./modules/grafana"

  grafana_namespace = "grafana"
  service_type      = "NodePort"
}


module "prometheus" {
  source = "./modules/prometheus"

  prometheus_namespace = "prometheus"
  service_type         = "NodePort"
}

module "azure_ssh_key" {
  source              = "./modules/azure_ssh_key"
  prefix              = "myproject"
  location            = azurerm_resource_group.my_rg.location
  resource_group_name = azurerm_resource_group.my_rg.name
  separator           = "-"
}

provider "azurerm" {
  features {}
}

terraform {
  required_version = ">=0.12"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
    azuread = {
      version = ">= 2.26.0" 
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.3"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.1.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.7.0"
    }
    azapi = {
      source  = "azure/azapi"
      version = "~> 1.12.0"
    }
  }
}

provider "kubectl" {
  config_path    = "~/.kube/config"
  config_context = "cluster-exciting-catfish"
}

provider "helm" {
  kubernetes {
    host                   = "https://dns-handy-baboon-xdksfsgf.hcp.koreacentral.azmk8s.io" # 수정됨
    client_certificate     = base64decode(data.azurerm_kubernetes_cluster.aks.kube_config.0.client_certificate)
    client_key             = base64decode(data.azurerm_kubernetes_cluster.aks.kube_config.0.client_key)
    cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.aks.kube_config.0.cluster_ca_certificate)
  }
}

provider "kubernetes" {
  host                   = "https://dns-handy-baboon-xdksfsgf.hcp.koreacentral.azmk8s.io" # 수정됨
  client_certificate     = base64decode(data.azurerm_kubernetes_cluster.aks.kube_config.0.client_certificate)
  client_key             = base64decode(data.azurerm_kubernetes_cluster.aks.kube_config.0.client_key)
  cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.aks.kube_config.0.cluster_ca_certificate)
}

output "gateway_frontend_ip" {
  value = "http://${azurerm_public_ip.appgw_public_ip.ip_address}"
}
