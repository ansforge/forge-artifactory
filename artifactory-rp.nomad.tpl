job "${nomad_namespace}-rp" {
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

    group "artifactory-rp" {
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
            port "artifactory-rp-http" { to = 80 }
            port "artifactory-rp-https" { to = 443 }
        }

        task "nginx" {
            driver = "docker"
            leader = true 

            template {
              change_mode = "noop"
              destination = "/secrets/default.key"
              perms       = "777"
              data        = <<EOH
      {{with secret "${vault_secrets_engine_name}"}}{{.Data.data.rp_private_key}}{{end}}
              EOH
            }

            template {
              change_mode = "noop"
              destination = "/secrets/default.crt"
              perms       = "777"
              data        = <<EOH
      {{with secret "${vault_secrets_engine_name}"}}{{.Data.data.rp_certificate}}{{end}}
              EOH
            }

            template {
                data = <<EOH
ART_BASE_URL="http://{{range service ( print (env "NOMAD_NAMESPACE") "-app-ep") }}{{ .Address }}:{{ .Port }}{{ end }}"
NGINX_LOG_ROTATE_COUNT=7
NGINX_LOG_ROTATE_SIZE=5M
SSL=false
TZ="Europe/Paris"

EOH
                destination = "secrets/file.env"
                change_mode = "restart"
                env = true
            }

            template {
                destination = "secrets/artifactory.conf"
                change_mode = "restart"
                perms = "755"
                data = <<EOH
ssl_protocols TLSv1 TLSv1.1 TLSv1.2 TLSv1.3;
ssl_certificate  /var/opt/jfrog/nginx/ssl/example.crt;
ssl_certificate_key  /var/opt/jfrog/nginx/ssl/example.key;
ssl_session_cache shared:SSL:1m;
ssl_prefer_server_ciphers   on;
## server configuration
server {
  listen 443 ssl;
  listen 80 ;
  server_name ~(?<repo>.+)\.artifactory artifactory;

  if ($http_x_forwarded_proto = '') {
    set $http_x_forwarded_proto  $scheme;
  }
  ## Application specific logs
  ## access_log /var/log/nginx/artifactory-access.log timing;
  ## error_log /var/log/nginx/artifactory-error.log;
  if ( $repo != "" ){
    rewrite ^/(v1|v2)/(.*) /artifactory/api/docker/$repo/$1/$2;
  }
  chunked_transfer_encoding on;
  client_max_body_size 0;
  location / {
    proxy_read_timeout  900;
    proxy_pass_header   Server;
    proxy_cookie_path   ~*^/.* /;
    proxy_pass          http://{{range service ( print (env "NOMAD_NAMESPACE") "-app-ep") }}{{ .Address }}:{{ .Port }}{{ end }};
    proxy_set_header    X-JFrog-Override-Base-Url $http_x_forwarded_proto://$host:$server_port;
    proxy_set_header    X-Forwarded-Port  $server_port;
    proxy_set_header    X-Forwarded-Proto $http_x_forwarded_proto;
    proxy_set_header    Host              $http_host;
    proxy_set_header    X-Forwarded-For   $proxy_add_x_forwarded_for;
    add_header Strict-Transport-Security always;

    if ($http_content_type = "application/grpc") {
        ## if tls is disabled in access, use 'grpc' protocol
        grpc_pass grpcs://{{range service ( print (env "NOMAD_NAMESPACE") "-app-ep") }}{{ .Address }}:{{ .Port }}{{ end }};
    }

    location ~ ^/artifactory/ {
        proxy_pass    http://{{range service ( print (env "NOMAD_NAMESPACE") "-app-svc") }}{{ .Address }}:{{ .Port }}{{ end }};
    }
  }
}
                EOH
            }

            config {
                image   = "${image}:${tag}"
                ports   = ["artifactory-rp-http","artifactory-rp-https"]
                volumes = ["name=$${NOMAD_JOB_NAME},io_priority=high,size=1,repl=2:/var/opt/jfrog/nginx"]
                volume_driver = "pxd"

                mount {
                  type     = "bind"
                  target   = "/var/opt/jfrog/nginx/conf.d/artifactory.conf"
                  source   = "secrets/artifactory.conf"
                  readonly = false
                }

            }

            resources {
                cpu    = ${rp_ressource_cpu}
                memory = ${rp_ressource_mem}
            }

            service {
                name = "$${NOMAD_JOB_NAME}-http"
                tags = ["urlprefix-artifactory.internal/"]
                port = "artifactory-rp-http"
                check {
                    name     = "alive"
                    type     = "tcp"
                    interval = "60s"
                    timeout  = "10s"
                    failures_before_critical = 5
                    port     = "artifactory-rp-http"
                }
            }

            service {
                name = "$${NOMAD_JOB_NAME}-https"
                #tags = ["urlprefix-rp.artifactory.internal/ proto=https tlsskipverify=true"]
                port = "artifactory-rp-https"
                check {
                    name     = "alive"
                    type     = "tcp"
                    interval = "60s"
                    timeout  = "10s"
                    failures_before_critical = 5
                    port     = "artifactory-rp-https"
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
