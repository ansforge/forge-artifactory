job "forge-artifactory-nginx" {
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
        change_mode = "restart"
    }
    group "artifactory-nginx" {
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
            port "artifactory-nginx-http" { to = 80 }
            port "artifactory-nginx-https" { to = 443 }
        }

        task "nginx" {
            driver = "docker"

            template {
                data = <<EOH

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
                uid = 104
                gid = 107
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
    proxy_pass          http://{{ range service "forge-artifactory-ep" }}{{ .Address }}:{{ .Port }}{{ end }};
    proxy_set_header    X-JFrog-Override-Base-Url $http_x_forwarded_proto://$host:$server_port;
    proxy_set_header    X-Forwarded-Port  $server_port;
    proxy_set_header    X-Forwarded-Proto $http_x_forwarded_proto;
    proxy_set_header    Host              $http_host;
    proxy_set_header    X-Forwarded-For   $proxy_add_x_forwarded_for;
    add_header Strict-Transport-Security always;

    if ($http_content_type = "application/grpc") {
        ## if tls is disabled in access, use 'grpc' protocol
        grpc_pass grpcs://{{ range service "forge-artifactory-ep" }}{{ .Address }}:{{ .Port }}{{ end }};
    }

    location ~ ^/artifactory/ {
        proxy_pass    http://{{ range service "forge-artifactory" }}{{ .Address }}:{{ .Port }}{{ end }};
    }
  }
}
                EOH
            }

            config {
                image   = "${image}:${tag}"
                ports   = ["artifactory-nginx-http","artifactory-nginx-https"]
                extra_hosts = ["artifactory.internal artifactory.internal.ep:$\u007Battr.unique.network.ip-address\u007D"]
                volumes = ["name=forge-artifactory-nginx-data,io_priority=high,size=1,repl=2:/var/opt/jfrog/nginx"]
                volume_driver = "pxd"

                mount {
                  type     = "bind"
                  target   = "/var/opt/jfrog/nginx/conf.d/artifactory.conf"
                  source   = "secrets/artifactory.conf"
                  readonly = false
                  bind_options {
                    propagation = "rshared"
                   }
                }
            }

            env {
                ART_BASE_URL="http://$\u007BNOMAD_HOST_ADDR_artifactory-entrypoints\u007D"
            }

            resources {
                cpu    = 1000
                memory = 2048
            }

            service {
                name = "$\u007BNOMAD_JOB_NAME\u007D-nginx"
                tags = ["urlprefix-artifactory.nginx/"
                       ]
                port = "artifactory-nginx-http"
                check {
                    name     = "alive"
                    type     = "tcp"
                    interval = "120s" #60s
                    timeout  = "5m" #10s
                    failures_before_critical = 10 #5
                    port     = "artifactory-nginx-http"
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
