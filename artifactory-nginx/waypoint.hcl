project = "forge/artifactory-nginx"

labels = { "domaine" = "forge" }

runner {
    enabled = true
    data_source "git" {
        url  = "https://github.com/ansforge/forge-artifactory.git"
        ref  = "var.datacenter"
        path = "artifactory-nginx"
        ignore_changes_outside_path = true
    }
}

app "forge/artifactory-nginx" {

    build {
        use "docker-pull" {
            image = var.image
            tag   = var.tag
            disable_entrypoint = true
        }
    }

    deploy{
        use "nomad-jobspec" {
            jobspec = templatefile("${path.app}/artifactory-nginx.nomad.tpl", {
            tag     = var.tag
	    image_nginx = var.image_nginx
            datacenter = var.datacenter
            external_url_artifactory_hostname = var.external_url_artifactory_hostname
            repo_url = var.repo_url
            })
        }
    }
}

variable "datacenter" {
    type    = string
    default = "test"
}


variable "image_nginx" {
    type    = string
    default = "jfrog/nginx-artifactory-pro"
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
