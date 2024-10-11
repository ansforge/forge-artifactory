job "forge-artifactory-mariadb" {
    datacenters = ["${datacenter}"]
    type = "service"
    vault {
        policies = ["forge"]
        change_mode = "restart"
    }
    group "artifactory-mariadb" {
        count ="1"
        
        restart {
            attempts = 3
            delay = "60s"
            interval = "1h"
            mode = "fail"
        }
        
        constraint {
            attribute = "$\u007Bnode.class\u007D"
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

{{ with secret "forge/artifactory" }}
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
                volumes = ["name=forge-artifactory-db,io_priority=high,size=2,repl=2:/var/lib/mysql"]
                volume_driver = "pxd"
            }
            
            resources {
                cpu    = 1000
                memory = 4096
            }
            
            service {
                name = "$\u007BNOMAD_JOB_NAME\u007D"
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
                INSTANCE = "$\u007BNOMAD_ALLOC_NAME\u007D"
            }
            template {
                data = <<EOH
REDIS_HOSTS = {{ range service "PileELK-redis" }}{{ .Address }}:{{ .Port }}{{ end }}
PILE_ELK_APPLICATION = ARTIFACTORY 
EOH
                destination = "local/file.env"
                change_mode = "restart"
                env = true
            }
            config {
                image = "ans/nomad-filebeat:8.2.3-2.1"
            }
            resources {
                cpu    = 50
                memory = 100
            }
        } #end log-shipper 

    }
}
