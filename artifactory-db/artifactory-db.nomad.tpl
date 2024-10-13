job "${nomad_namespace}-db" {
    datacenters = ["${datacenter}"]
	namespace   = "${nomad_namespace}"
	
    type = "service"
	
    vault {
        policies = ["${vault_acl_policy_name}"]
        change_mode = "restart"
    }
    group "artifactory-db" {
        count ="1"
        
        restart {
            attempts = 3
            delay = "60s"
            interval = "1h"
            mode = "fail"
        }
        
        constraint {
            attribute = "$${node.class}"
            value     = "data"
        }

        network {
            port "mariadb" { to = 3306 }
        }
        
        task "mariadb" {
            driver = "docker"

            # log-shipper
            leader = true 

            template {
                data = <<EOH

{{ with secret "${vault_secrets_engine_name}" }}
MYSQL_ROOT_PASSWORD="{{ .Data.data.root_password }}"
MYSQL_DB="{{ .Data.data.db_name }}"
MYSQL_USER="{{ .Data.data.psql_username }}"
MYSQL_PASSWORD="{{ .Data.data.psql_password }}"
{{ end }}

                EOH
                destination = "secrets/file.env"
                change_mode = "restart"
                env = true
            }

            config {
                image   = "${image}:${tag}"
                command = "--max_allowed_packet=8M --innodb_buffer_pool_size=1536M --tmp_table_size=512M --max_heap_table_size=512M --innodb_log_file_size=256M --innodb_log_buffer_size=4M"
                ports   = ["mariadb"]
                volumes = ["name=$${NOMAD_JOB_NAME},io_priority=high,size=20,repl=2:/var/lib/mysql"]
                volume_driver = "pxd"
            }
            
            resources {
                cpu    = ${db_ressource_cpu}
                memory = ${db_ressource_mem}
            }
            
            service {
                name = "$${NOMAD_JOB_NAME}"
                port = "mariadb"
                tags = ["urlprefix-:3307 proto=tcp"]
                check {
                    name     = "alive"
                    type     = "tcp"
                    interval = "30s"
                    timeout  = "5s"
                    port     = "mariadb"
                }
            }
        }

        # log-shipper
        task "log-shipper" {
            driver = "docker"
            restart {
                    interval = "3m"
                    attempts = 5
                    delay    = "15s"
                    mode     = "delay"
            }
            meta {
                INSTANCE = "$${NOMAD_ALLOC_NAME}"
            }
            template {
                data = <<EOH
REDIS_HOSTS = {{ range service "PileELK-redis" }}{{ .Address }}:{{ .Port }}{{ end }}
PILE_ELK_APPLICATION = ${nomad_namespace}
EOH
                destination = "local/file.env"
                change_mode = "restart"
                env = true
            }
            config {
                image = "${log_shipper_image}:${log_shipper_tag}"
            }
            resources {
                cpu    = 100
                memory = 150
            }
        } #end log-shipper 

    }
}
