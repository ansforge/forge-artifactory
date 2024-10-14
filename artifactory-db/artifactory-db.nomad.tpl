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
			
            template {
                data = <<EOT
[client]
port            = 3306
socket          = /var/run/mysqld/mysqld.sock

[mysqld_safe]
socket          = /var/run/mysqld/mysqld.sock
nice            = 0

[mysqld]
#user           = mysql
pid-file        = /var/run/mysqld/mysqld.pid
socket          = /var/run/mysqld/mysqld.sock
port            = 3306
basedir         = /usr
datadir         = /var/lib/mysql
tmpdir          = /tmp
lc_messages_dir = /usr/share/mysql
lc_messages     = en_US
skip-external-locking
max_connections         = 100
connect_timeout         = 5
wait_timeout            = 600
max_allowed_packet      = 16M
thread_cache_size       = 128
sort_buffer_size        = 4M
bulk_insert_buffer_size = 16M
tmp_table_size          = 512M
max_heap_table_size     = 512M

myisam_recover_options = BACKUP
key_buffer_size         = 128M
#open-files-limit       = 2000
table_open_cache        = 400
myisam_sort_buffer_size = 512M
concurrent_insert       = 2
read_buffer_size        = 2M
read_rnd_buffer_size    = 1M

query_cache_limit               = 128K
query_cache_size                = 64M

slow_query_log_file     = /var/log/mysql/mariadb-slow.log
long_query_time = 10

expire_logs_days        = 10
max_binlog_size         = 100M

default_storage_engine  = InnoDB
innodb_buffer_pool_size = 1536M
innodb_log_file_size    = 256M
innodb_log_buffer_size  = 4M
innodb_file_per_table   = 1
innodb_open_files       = 400
innodb_io_capacity      = 400
innodb_flush_method     = O_DIRECT

[galera]

[mysqldump]
quick
quote-names
max_allowed_packet      = 16M

[mysql]

[isamchk]
key_buffer              = 16M

!includedir /etc/mysql/conf.d/

                EOT
                destination = "secrets/my.cnf"
                change_mode = "restart"
                perms = "755"
                env = true
            }

            config {
                image   = "${image}:${tag}"
                command = "--max_allowed_packet=8M --innodb_buffer_pool_size=1536M --tmp_table_size=512M --max_heap_table_size=512M --innodb_log_file_size=256M --innodb_log_buffer_size=4M"
                ports   = ["mariadb"]
                volumes = ["name=$${NOMAD_JOB_NAME},io_priority=high,size=20,repl=2:/var/lib/mysql"]
                volume_driver = "pxd"
				
                mount {
                  type     = "bind"
                  target   = "/etc/mysql/my.cnf"
                  source   = "secrets/my.cnf"
                  readonly = false
                  bind_options {
                    propagation = "rshared"
                   }
                }
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
