job "forge-artifactory-app" {
    datacenters = ["${datacenter}"]
    type = "service"

    update {
        health_check      = "checks"
        min_healthy_time  = "10s"
        healthy_deadline  = "10m"
        progress_deadline = "15m"
    }

    vault {
        policies = ["forge","smtp"]
        change_mode = "noop"
    }
    group "artifactory" {
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
            port "artifactory" { to = 8081 }
            port "artifactory-entrypoints" { to = 8082 }
        }

        task "artifactory" {
            driver = "docker"

        artifact {
          source = "${repo_url}/artifactory/ext-release-local/org/mariadb/jdbc/mariadb-java-client/2.7.1/mariadb-java-client-2.7.1.jar"
          options {
            archive = false
          }
       }

            template {
                destination = "secrets/system.yaml"
                change_mode = "restart"
                perms = "777"
                uid = 1030
                gid = 1030
                data = <<EOH
## @formatter:off
## JFROG ARTIFACTORY SYSTEM CONFIGURATION FILE
## HOW TO USE: comment-out any field and keep the correct yaml indentation by deleting only the leading '#' character.
configVersion: 1
## NOTE: JFROG_HOME is a place holder for the JFrog root directory containing the deployed product, the home directory for all JFrog products.
## Replace JFROG_HOME with the real path! For example, in RPM install, JFROG_HOME=/opt/jfrog

## NOTE: Sensitive information such as passwords and join key are encrypted on first read.
## NOTE: The provided commented key and value is the default.

## SHARED CONFIGURATIONS
## A shared section for keys across all services in this config
shared:
    ## Security Configuration
    security:
    ## Join key value for joining the cluster (takes precedence over 'joinKeyFile')
    #joinKey: "<Your joinKey>"

    ## Join key file location
    #joinKeyFile: "<For example: JFROG_HOME/artifactory/var/etc/security/join.key>"

    ## Master key file location
    ## Generated by the product on first startup if not provided
    #masterKeyFile: "<For example: JFROG_HOME/artifactory/var/etc/security/master.key>"

    ## Maximum time to wait for key files (master.key and join.key)
    #bootstrapKeysReadTimeoutSecs: 120

    ## Node Settings
    node:
    ## A unique id to identify this node.
    ## Default auto generated at startup.
    #id: "art1"

    ## Default auto resolved by startup script
    #ip:

    ## Sets this node as primary in HA installation
    #primary: true

    ## Sets this node as part of HA installation
    #haEnabled: true

    ## Database Configuration
    database:
        ## Example for postgresql
        type: mariadb
        ## One of mysql, oracle, mssql, postgresql, mariadb
        ## Default Embedded derby

        driver: org.mariadb.jdbc.Driver
{{range service ( "forge-artifactory-mariadb") }}
        url: jdbc:mariadb://{{.Address}}:{{.Port}}/artdb?characterEncoding=UTF-8&elideSetAutoCommits=true&useSSL=false&useMysqlMetadata=true
{{end}}
        username: {{ with secret "forge/artifactory" }}{{ .Data.data.psql_username }}{{ end }}
        password: {{ with secret "forge/artifactory" }}{{ .Data.data.psql_password }}{{ end }}

                EOH
            }

            config {
                image   = "${image}:${tag}"
                ports   = ["artifactory","artifactory-entrypoints"]
                volumes = ["name=forge-artifactory-data,io_priority=high,size=5,repl=2:/var/opt/jfrog/artifactory"]
                volume_driver = "pxd"

                mount {
                  type     = "bind"
                  target   = "/opt/jfrog/artifactory/var/etc/system.yaml"
                  source   = "secrets/system.yaml"
                  readonly = false
                  bind_options {
                    propagation = "rshared"
                   }
                }

               mount {
                  type   = "bind"
                  target = "/opt/jfrog/artifactory/var/bootstrap/artifactory/tomcat/lib/mariadb-java-client-2.7.1.jar"
                  source = "local/mariadb-java-client-2.7.1.jar"
                  bind_options {
                    propagation = "rshared"
                  }
              }

            }

            env {
               JF_ROUTER_ENTRYPOINTS_EXTERNALPORT = "8082"
            }

            resources {
                cpu    = 500
                memory = 4096
            }
            
            service {
                name = "$\u007BNOMAD_JOB_NAME\u007D"
                port = "artifactory"
                check {
                    name     = "alive"
                    type     = "tcp"
                    interval = "120s" #60s
                    timeout  = "5m" #10s
                    failures_before_critical = 10 #5
                    port     = "artifactory"
                }
            }

            service {
                name = "$\u007BNOMAD_JOB_NAME\u007D-ep"
                tags = ["urlprefix-${external_url_artifactory_hostname}/",
                        "urlprefix-artifactory.internal/"
                       ]
                port = "artifactory-entrypoints"
                check {
                    name     = "alive"
                    type     = "tcp"
                    interval = "120s" #60s
                    timeout  = "5m" #10s
                    failures_before_critical = 10 #5
                    port     = "artifactory-entrypoints"
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
