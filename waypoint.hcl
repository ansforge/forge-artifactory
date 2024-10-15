project = "${workspace.name}" # exemple : forge-artifactory-dev

labels = { "domaine" = "forge" }

runner {
    enabled = true
    profile = "common-odr"
    data_source "git" {
        url  = "https://github.com/ansforge/forge-artifactory.git"
        ref  = "var.datacenter"
    }
    poll {
      # à mettre à true pour déployer automatiquement en cas de changement dans la branche
      enabled = false
      # interval = "60s"
    }
}


app "artifactory-db" {

    build {
        use "docker-ref" {
          image = var.database_image
          tag   = var.database_tag
        }
    }
  
    deploy{
        use "nomad-jobspec" {
          jobspec = templatefile("${path.app}/artifactory-db.nomad.tpl", {
            
	  datacenter = var.datacenter           
	  nomad_namespace = var.nomad_namespace
          vault_acl_policy_name = var.vault_acl_policy_name
          vault_secrets_engine_name = var.vault_secrets_engine_name
			
	  image = var.database_image
          tag = var.database_tag
	  db_ressource_cpu = var.db_ressource_cpu
	  db_ressource_mem = var.db_ressource_mem
			
	  log_shipper_image = var.log_shipper_image
	  log_shipper_tag = var.log_shipper_tag
          })
        }
    }
}

app "artifactory-app" {

    build {
        use "docker-ref" {
          image = var.app_image
          tag = var.app_tag
        }
    }

    deploy{
        use "nomad-jobspec" {
          jobspec = templatefile("${path.app}/artifactory-app.nomad.tpl", {
            datacenter = var.datacenter
	    nomad_namespace  = var.nomad_namespace
	    vault_acl_policy_name = var.vault_acl_policy_name
	    vault_secrets_engine_name = var.vault_secrets_engine_name
			
	    image = var.app_image
	    tag = var.app_tag
            app_ressource_cpu = var.app_ressource_cpu
	    app_ressource_mem = var.app_ressource_mem            
            external_url_artifactory_hostname = var.external_url_artifactory_hostname
            repo_url = var.repo_url
			
	    log_shipper_image = var.log_shipper_image
	    log_shipper_tag = var.log_shipper_tag
          })
        }
    }
}

app "artifactory-rp" {

    build {
        use "docker-ref" {
          image = var.rp_image
          tag   = var.rp_tag
        }
    }

    deploy{
        use "nomad-jobspec" {
          jobspec = templatefile("${path.app}/artifactory-rp.nomad.tpl", {
            datacenter = var.datacenter
	    nomad_namespace = var.nomad_namespace
	    vault_acl_policy_name = var.vault_acl_policy_name
	    vault_secrets_engine_name = var.vault_secrets_engine_name
			
	    image = var.rp_image
            tag = var.rp_tag
	    rp_ressource_cpu = var.rp_ressource_cpu
            rp_ressource_mem = var.rp_ressource_mem
			
	    log_shipper_image = var.log_shipper_image
	    log_shipper_tag = var.log_shipper_tag			
          })
        }
    }
}

app "artifactory-backup" {

    build {
        use "docker-ref" {
          image = var.backup_image
          tag   = var.backup_tag
        }
    }

    deploy{
        use "nomad-jobspec" {
          jobspec = templatefile("${path.app}/artifactory-backup.nomad.tpl", {
            datacenter = var.datacenter
	    nomad_namespace = var.nomad_namespace
	    vault_acl_policy_name = var.vault_acl_policy_name
	    vault_secrets_engine_name = var.vault_secrets_engine_name
			
	    image = var.backup_image
            tag = var.backup_tag
	    backup_db_ressource_cpu = var.backup_db_ressource_cpu
	    backup_db_ressource_mem = var.backup_db_ressource_mem
	    backup_cron = var.backup_cron
			
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

# --- DB ---

variable "database_image" {
  type    = string
  default = "mariadb"
}

variable "database_tag" {
  type    = string
  default = "10.2.33"
}

variable "db_ressource_cpu" {
  type    = number
  default = 1000
}

variable "db_ressource_mem" {
  type    = number
  default = 4096
}

# --- APP ---

variable "app_image" {
  type    = string
  default = "jfrog/artifactory-pro"
}

variable "app_tag" {
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

# --- RP ---   

variable "rp_image" {
  type    = string
  default = "jfrog/nginx-artifactory-pro"
}

variable "rp_tag" {
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

# --- BACKUP ---   

variable "backup_image" {
  type    = string
  default = "ans/mariadb-ssh"
}

variable "backup_tag" {
  type    = string
  default = "10.2.33"
}

variable "backup_cron" {
  type    = string
  default = "0 04 * * *"
}

variable "backup_db_ressource_cpu" {
  type    = number
  default = 2048
}

variable "backup_db_ressource_mem" {
  type    = number
  default = 512
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
