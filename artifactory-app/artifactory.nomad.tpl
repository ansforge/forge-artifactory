job "forge-artifactory" {
    datacenters = ["${datacenter}"]
    type = "service"

    update {
        # max_parallel      = 3
        health_check      = "checks"
        min_healthy_time  = "10s"
        healthy_deadline  = "10m"
        progress_deadline = "15m"
        # auto_revert       = true
        # auto_promote      = true
        # canary            = 1
        # stagger           = "30s"
    }

    vault {
        policies = ["forge","smtp"]
        change_mode = "restart"
    }
    group "artifactory-server" {
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
            port "artifactory-http" { to = 8081 }
            port "artifactory-entrypoints" { to = 8082 }
        }

        task "artifactory" {
            driver = "docker"

            # log-shipper
            leader = true

            template {
                data = <<EOH
JF_ROUTER_ENTRYPOINTS_EXTERNALPORT="8082"
TZ="Europe/Paris"
EOH
                destination = "secrets/file.env"
                change_mode = "restart"
                env = true
            }

            template {
                destination = "secrets/artifactory.ans.rb"
                change_mode = "restart"
                data = <<EOH


                EOH
            }

            config {
                extra_hosts = [ "jenkins.internal:$\u007Battr.unique.network.ip-address\u007D"
                              ]
                image   = "${image}:${tag}"
                ports   = ["artifactory-http", "artifactory-entrypoints"]
                volumes = ["name=forge-artifactory-data,io_priority=high,size=5,repl=2:/var/opt/jfrog/artifactory"]
                volume_driver = "pxd"
            }

            resources {
                cpu    = 4000
                memory = 14336
            }
            
            service {
                name = "$\u007BNOMAD_JOB_NAME\u007D"
                tags = ["urlprefix-artifactory.internal/"
                       ]
                port = "artifactory"
                check {
                    name     = "alive"
                    type     = "tcp"
                    interval = "120s" #60s
                    timeout  = "5m" #10s
                    failures_before_critical = 10 #5
                    port     = "artifactory-http"
                }
            }
        }

        task "nginx" {
            driver = "docker"

            # log-shipper
            leader = true

            template {
                data = <<EOH
ART_BASE_URL=http://localhost:8082
NGINX_LOG_ROTATE_COUNT=${NGINX_LOG_ROTATE_COUNT}
NGINX_LOG_ROTATE_SIZE=${NGINX_LOG_ROTATE_SIZE}
SSL=true
TZ="Europe/Paris"
EOH
                destination = "secrets/file.env"
                change_mode = "restart"
                env = true
            }

            template {
                destination = "secrets/nginx.ans.rb"
                change_mode = "restart"
                data = <<EOH


                EOH
            }

            config {
                image   = "${image_nginx}:${tag}"
                ports   = ["artifactory-entrypoints"]
                volumes = ["name=forge-nginx-data,io_priority=high,size=2,repl=2:/var/opt/jfrog/nginx"]
                volume_driver = "pxd"
            }

            resources {
                cpu    = 1000
                memory = 2048
            }
            
            service {
                name = "$\u007BNOMAD_JOB_NAME\u007D"
                tags = ["urlprefix-${external_url_artifactory_hostname}/"
                       ]
                port = "artifactory"
                check {
                    name     = "alive"
                    type     = "tcp"
                    interval = "120s" #60s
                    timeout  = "5m" #10s
                    failures_before_critical = 10 #5
                    port     = "artifactory-http"
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
