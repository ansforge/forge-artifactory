project = "${workspace.name}"

labels = { "domaine" = "forge" }

runner {
    enabled = true
	profile = "common-odr"
    data_source "git" {
        url  = "https://github.com/ansforge/forge-artifactory.git"
        ref  = "var.datacenter"
        path = "artifactory-app"
        ignore_changes_outside_path = true
    }
}

app "artifactory-app" {

    build {
        use "docker-ref" {
            image = var.image
            tag   = var.tag
        }
    }

    deploy{
        use "nomad-jobspec" {
            jobspec = templatefile("${path.app}/artifactory.nomad.tpl", {
            datacenter = var.datacenter
			nomad_namespace  = var.nomad_namespace
			vault_acl_policy_name     = var.vault_acl_policy_name
			vault_secrets_engine_name = var.vault_secrets_engine_name
			
			image   = var.image
			tag     = var.tag
            app_ressource_cpu = var.app_ressource_cpu
			app_ressource_mem = var.app_ressource_mem            
            external_url_artifactory_hostname = var.external_url_artifactory_hostname
            repo_url = var.repo_url
			
			log_shipper_image = var.log_shipper_image
			log_shipper_tag   = var.log_shipper_tag
            })
        }
    }
}

# ${workspace.name} : waypoint workspace name

variable "datacenter" {
    type    = string
    default = "test"
}

variable "nomad_namespace" {
  type    = string
  default = "${workspace.name}"
}

variable "vault_acl_policy_name" {
  type    = string
  default = "${workspace.name}"
}

variable "vault_secrets_engine_name" {
  type    = string
  default = "${workspace.name}"
}

# APP
variable "image" {
    type    = string
    default = "jfrog/artifactory-pro"
}

variable "tag" {
    type    = string
    default = "7.63.14"
}

variable "external_url_artifactory_hostname" {
    type    = string
    default = "repo.forge.asipsante.fr"
}

variable "repo_url" {
    type    = string
    default = "http://repo.proxy-dev-forge.asip.hst.fluxus.net"
}

variable "app_ressource_cpu" {
  type    = number
  default = 1000
}

variable "app_ressource_mem" {
  type    = number
  default = 4096
}

# --- log-shipper ---

variable "log_shipper_image" {
  type    = string
  default = "ans/nomad-filebeat"
}

variable "log_shipper_tag" {
  type    = string
  default = "8.2.3-2.1"
}
