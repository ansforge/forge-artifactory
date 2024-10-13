project = "${workspace.name}"

labels = { "domaine" = "forge" }

runner {
    enabled = true
    profile = "common-odr"
    data_source "git" {
        url  = "https://github.com/ansforge/forge-artifactory.git"
        ref  = "var.datacenter"
        path = "artifactory-nginx"
        ignore_changes_outside_path = true
    }
}

app "artifactory-rp" {

    build {
        use "docker-ref" {
            image = var.image
            tag   = var.tag
        }
    }

    deploy{
        use "nomad-jobspec" {
            jobspec = templatefile("${path.app}/artifactory-nginx.nomad.tpl", {
            datacenter = var.datacenter
	    nomad_namespace = var.nomad_namespace
	    vault_acl_policy_name = var.vault_acl_policy_name
	    vault_secrets_engine_name = var.vault_secrets_engine_name
			
	    image = var.image
            tag = var.tag
	    rp_ressource_cpu = var.rp_ressource_cpu
            rp_ressource_mem = var.rp_ressource_mem
			
	    log_shipper_image = var.log_shipper_image
	    log_shipper_tag = var.log_shipper_tag			
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

# --- RP ---   

variable "image" {
    type    = string
    default = "jfrog/nginx-artifactory-pro"
}

variable "tag" {
    type    = string
    default = "7.63.14"
}

variable "rp_ressource_cpu" {
  type    = number
  default = 1000
}

variable "rp_ressource_mem" {
  type    = number
  default = 2048
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
