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
            tag     = var.tag
            image   = var.image
            datacenter = var.datacenter
            repo_url = var.repo_url
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
    default = "jfrog/artifactory-pro"
}

variable "tag" {
    type    = string
    default = "7.63.14"
}

variable "repo_url" {
    type    = string
    default = "http://repo.proxy-dev-forge.asip.hst.fluxus.net"
}
