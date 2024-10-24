job "${nomad_namespace}-app" {
    datacenters = ["${datacenter}"]
    namespace   = "${nomad_namespace}"
	
    type = "service"

    update {
        health_check      = "checks"
        min_healthy_time  = "10s"
        healthy_deadline  = "10m"
        progress_deadline = "15m"
    }

    vault {
        policies = ["${vault_acl_policy_name}","smtp"]
        change_mode = "restart"
    }
    group "artifactory-app" {
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
            port "artifactory-svc" { to = 8081 }
            port "artifactory-entrypoints" { to = 8082 }
        }

        volume "artifactory-filestore" {
            type = "csi"
            read_only = false
            source = "nfs-artifactory"
            attachment_mode = "file-system"
            access_mode = "multi-node-multi-writer"        
        }

        task "artifactory" {

            volume_mount {
              volume = "artifactory-filestore"
              destination = "/var/opt/jfrog/artifactory/data/artifactory/filestore"
              read_only = false
            }

            driver = "docker"
            leader = true 

            artifact {
              source = "${repo_url}/artifactory/ext-release-local/org/mariadb/jdbc/mariadb-java-client/2.7.1/mariadb-java-client-2.7.1.jar"
              options {
                archive = false
              }
           }

            template {
                destination = "secrets/system.yaml"
                change_mode = "noop"
                perms = "777"
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

        url: jdbc:mariadb://{{range service ( print (env "NOMAD_NAMESPACE") "-db") }}{{.Address}}:{{.Port}}{{end}}/{{with secret "${vault_secrets_engine_name}"}}{{ .Data.data.db_name }}{{ end }}?characterEncoding=UTF-8&elideSetAutoCommits=true&useSSL=false&useMysqlMetadata=true

        username: {{with secret "${vault_secrets_engine_name}"}}{{ .Data.data.psql_username }}{{ end }}
        password: {{with secret "${vault_secrets_engine_name}"}}{{ .Data.data.psql_password }}{{ end }}

                EOH
            }

            template {
                destination = "secrets/master.key"
                change_mode = "noop"
                perms = "755"
                data = <<EOH
{{with secret "${vault_secrets_engine_name}"}}{{ .Data.data.masterkey }}{{ end }}
                EOH
            }

            template {
                destination = "secrets/binarystore.xml"
                change_mode = "noop"
                perms = "755"
                data = <<EOH
<config version="1">
    <chain template="file-system"/>
    <provider id="file-system" type="file-system">
        <baseDataDir>/var/opt/jfrog/artifactory/data/artifactory</baseDataDir>
    </provider>
</config>
                EOH
            }

            config {
                image   = "${image}:${tag}"
                ports   = ["artifactory-svc","artifactory-entrypoints"]
                volumes = ["name=$${NOMAD_JOB_NAME},io_priority=high,size=20,repl=2:/var/opt/jfrog/artifactory"]
                volume_driver = "pxd"

                mount {
                  type     = "bind"
                  target   = "/opt/jfrog/artifactory/var/etc/system.yaml"
                  source   = "secrets/system.yaml"
                  readonly = false
                }

                mount {
                  type     = "bind"
                  target   = "/opt/jfrog/artifactory/var/etc/security/master.key"
                  source   = "secrets/master.key"
                  readonly = false
                }

                mount {
                  type     = "bind"
                  target   = "/opt/jfrog/artifactory/var/etc/artifactory/binarystore.xml"
                  source   = "secrets/binarystore.xml"
                  readonly = false
                }

               mount {
                  type   = "bind"
                  target = "/opt/jfrog/artifactory/var/bootstrap/artifactory/tomcat/lib/mariadb-java-client-2.7.1.jar"
                  source = "local/mariadb-java-client-2.7.1.jar"
              }

            }

            env {
               JF_ROUTER_ENTRYPOINTS_EXTERNALPORT = "8082"
            }

            resources {
                cpu    = ${app_ressource_cpu}
                memory = ${app_ressource_mem}
            }
            
            service {
                name = "$${NOMAD_JOB_NAME}-svc"
                tags = ["urlprefix-${external_url_artifactory_hostname}/artifactory"]
                port = "artifactory-svc"
                check {
                    name     = "alive"
                    type     = "tcp"
                    interval = "120s" #60s
                    timeout  = "5m" #10s
                    failures_before_critical = 10 #5
                    port     = "artifactory-svc"
                }
            }

            service {
                name = "$${NOMAD_JOB_NAME}-ep"
                tags = ["urlprefix-${external_url_artifactory_hostname}/"]
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
                cpu    = 50
                memory = 100
            }
        } #end log-shipper  
    }
}
