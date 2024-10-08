project = "forge/artifactory"

labels = { "domaine" = "forge" }

runner {
    enabled = true
    data_source "git" {
        url  = "https://github.com/ansforge/forge-artifactory.git"
        ref  = "var.datacenter"
        path = "artifactory-app"
        ignore_changes_outside_path = true
    }
}

app "forge/artifactory-app" {

    build {
        use "docker-pull" {
            image = var.image
            tag   = var.tag
            disable_entrypoint = true
        }
    }

    deploy{
        use "nomad-jobspec" {
            jobspec = templatefile("${path.app}/artifactory.nomad.tpl", {
            image   = var.image
            tag     = var.tag
			image_nginx = var.image_nginx
            datacenter = var.datacenter
            external_url_artifactory_hostname = var.external_url_artifactory_hostname
            })
        }
    }
}

variable "datacenter" {
    type    = string
    default = "test"
}

variable "image" {
    type    = string
    default = "artifactory-pro"
}

variable "image_nginx" {
    type    = string
    default = "nginx-artifactory-pro"
}

variable "tag" {
    type    = string
    default = "7.90.13"
}

variable "external_url_artifactory_hostname" {
    type    = string
    default = "repo.forge.asipsante.fr"
}

variable "NGINX_LOG_ROTATE_COUNT" {
    type    = string
    default = "100"
}

variable "NGINX_LOG_ROTATE_SIZE" {
    type    = string
    default = "50M"
}
