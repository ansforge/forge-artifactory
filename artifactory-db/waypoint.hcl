project = "forge/artifactory-db"

labels = { "domaine" = "forge" }

runner {
    enabled = true
    data_source "git" {
        url  = "https://github.com/ansforge/forge-artifactory.git"
        ref  = "var.datacenter"
        path = "artifactory-db"
        ignore_changes_outside_path = true
    }
}

app "forge/artifactory-db" {

    build {
        use "docker-pull" {
            image = var.image
            tag   = var.tag
            disable_entrypoint = true
        }
    }
  
    deploy{
        use "nomad-jobspec" {
            jobspec = templatefile("${path.app}/artifactory-db.nomad.tpl", {
            image   = var.image
            tag     = var.tag
            datacenter = var.datacenter
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
    default = "mariadb"
}

variable "tag" {
    type    = string
    default = "10.2.33"
}
