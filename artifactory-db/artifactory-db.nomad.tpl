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
                data = <<EOH
# MariaDB database server configuration file.
#
# You can copy this file to one of:
# - "/etc/mysql/my.cnf" to set global options,
# - "~/.my.cnf" to set user-specific options.
# 
# One can use all long options that the program supports.
# Run program with --help to get a list of available options and with
# --print-defaults to see which it would actually understand and use.
#
# For explanations see
# http://dev.mysql.com/doc/mysql/en/server-system-variables.html

# This will be passed to all mysql clients
# It has been reported that passwords should be enclosed with ticks/quotes
# escpecially if they contain "#" chars...
# Remember to edit /etc/mysql/debian.cnf when changing the socket location.
#[client]
#port            = 3306
#socket          = /var/run/mysqld/mysqld.sock

# Here is entries for some specific programs
# The following values assume you have at least 32M ram

# This was formally known as [safe_mysqld]. Both versions are currently parsed.
[mysqld_safe]
socket          = /var/run/mysqld/mysqld.sock
nice            = 0

[mysqld]
#
# * Basic Settings
#
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
#
# Instead of skip-networking the default is now to listen only on
# localhost which is more compatible and is not less secure.
#bind-address           = 127.0.0.1
#
# * Fine Tuning
#
max_connections         = 100
connect_timeout         = 5
wait_timeout            = 600
max_allowed_packet      = 16M
thread_cache_size       = 128
sort_buffer_size        = 4M
bulk_insert_buffer_size = 16M
tmp_table_size          = 512M
max_heap_table_size     = 512M
#
# * MyISAM
#
# This replaces the startup script and checks MyISAM tables if needed
# the first time they are touched. On error, make copy and try a repair.
myisam_recover_options = BACKUP
key_buffer_size         = 128M
#open-files-limit       = 2000
table_open_cache        = 400
myisam_sort_buffer_size = 512M
concurrent_insert       = 2
read_buffer_size        = 2M
read_rnd_buffer_size    = 1M
#
# * Query Cache Configuration
#
# Cache only tiny result sets, so we can fit more in the query cache.
query_cache_limit               = 128K
query_cache_size                = 64M
# for more write intensive setups, set to DEMAND or OFF
#query_cache_type               = DEMAND
#
# * Logging and Replication
#
# Both location gets rotated by the cronjob.
# Be aware that this log type is a performance killer.
# As of 5.1 you can enable the log at runtime!
#general_log_file        = /var/log/mysql/mysql.log
#general_log             = 1
#
# Error logging goes to syslog due to /etc/mysql/conf.d/mysqld_safe_syslog.cnf.
#
# we do want to know about network errors and such
#log_warnings           = 2
#
# Enable the slow query log to see queries with especially long duration
#slow_query_log[={0|1}]
slow_query_log_file     = /var/log/mysql/mariadb-slow.log
long_query_time = 10
#log_slow_rate_limit    = 1000
#log_slow_verbosity     = query_plan

#log-queries-not-using-indexes
#log_slow_admin_statements
#
# The following can be used as easy to replay backup logs or for replication.
# note: if you are setting up a replication slave, see README.Debian about
#       other settings you may need to change.
#server-id              = 1
#report_host            = master1
#auto_increment_increment = 2
#auto_increment_offset  = 1
#log_bin                        = /var/log/mysql/mariadb-bin
#log_bin_index          = /var/log/mysql/mariadb-bin.index
# not fab for performance, but safer
#sync_binlog            = 1
expire_logs_days        = 10
max_binlog_size         = 100M
# slaves
#relay_log              = /var/log/mysql/relay-bin
#relay_log_index        = /var/log/mysql/relay-bin.index
#relay_log_info_file    = /var/log/mysql/relay-bin.info
#log_slave_updates
#read_only
#
# If applications support it, this stricter sql_mode prevents some
# mistakes like inserting invalid dates etc.
#sql_mode               = NO_ENGINE_SUBSTITUTION,TRADITIONAL
#
# * InnoDB
#
# InnoDB is enabled by default with a 10MB datafile in /var/lib/mysql/.
# Read the manual for more InnoDB related options. There are many!
default_storage_engine  = InnoDB
innodb_buffer_pool_size = 1536M
innodb_log_file_size    = 256M
innodb_log_buffer_size  = 4M
innodb_file_per_table   = 1
innodb_open_files       = 400
innodb_io_capacity      = 400
innodb_flush_method     = O_DIRECT

#
# * Security Features
#
# Read the manual, too, if you want chroot!
# chroot = /var/lib/mysql/
#
# For generating SSL certificates I recommend the OpenSSL GUI "tinyca".
#
# ssl-ca=/etc/mysql/cacert.pem
# ssl-cert=/etc/mysql/server-cert.pem
# ssl-key=/etc/mysql/server-key.pem

#
# * Galera-related settings
#
[galera]
# Mandatory settings
#wsrep_on=ON
#wsrep_provider=
#wsrep_cluster_address=
#binlog_format=row
#default_storage_engine=InnoDB
#innodb_autoinc_lock_mode=2
#
# Allow server to accept connections on all interfaces.
#
#bind-address=0.0.0.0
#
# Optional setting
#wsrep_slave_threads=1
#innodb_flush_log_at_trx_commit=0

[mysqldump]
quick
quote-names
max_allowed_packet      = 16M

[mysql]
#no-auto-rehash # faster start of mysql but no tab completion

[isamchk]
key_buffer              = 16M

#
# * IMPORTANT: Additional settings that can override those from this file!
#   The files must end with '.cnf', otherwise they'll be ignored.
#
!includedir /etc/mysql/conf.d/
# 
                EOH
                destination = "secrets/my.cnf"
                change_mode = "restart"
                perms = "755"
                env = false
            }

            config {
                image   = "${image}:${tag}"
                volumes = ["name=$${NOMAD_JOB_NAME},io_priority=high,size=20,repl=2:/var/lib/mysql"]
                ports   = ["mariadb"]
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
