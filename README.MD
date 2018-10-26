Author: Aysad Kozanoglu email: aysadx@gmail.com 


# MariaDB Master-to-Master replication

node-db1
node-db2

##### mariaDB server install on both nodes
```bash
apt-get install software-properties-common
apt-key adv --recv-keys --keyserver keyserver.ubuntu.com 0xcbcb082a1bb943db
add-apt-repository 'deb [arch=amd64,i386,ppc64el] http://www.ftp.saix.net/DB/mariadb/repo/10.1/debian  jessie main'
apt-get update
apt-get install mariadb-server
mysql_secure_installation
```
<br>

### /etc/mysql/my.cnf

##### on node-db1 
```mysql
...

# MASTER REPLICATION

server-id                = 10
report_host              = node-db1
log_bin                  = /var/log/mysql/mariadb-bin
log_bin_index            = /var/log/mysql/mariadb-bin.index
relay_log                = /var/log/mysql/relay-bin
relay_log_index          = /var/log/mysql/relay-bin.index
# replicate-do-db        = testdb
auto_increment_increment = 5
auto_increment_offset    = 1

...
```
service mysql restart; service mysql status;


##### on node-db2
```mysql
...

# Master replication

server-id                = 11
report_host              = node-db2
log_bin                  = /var/log/mysql/mariadb-bin
log_bin_index            = /var/log/mysql/mariadb-bin.index
relay_log                = /var/log/mysql/relay-bin
relay_log_index          = /var/log/mysql/relay-bin.index
# replicate-do-db        = testdb
auto_increment_increment = 5
auto_increment_offset    = 2

...
```

###### on both nodes
```service mysql restart; service mysql status;```

<br>

#### Set Master and create replication user on both nodes
##### on node-db2
 get MASTER_LOG_POS and  MASTER_LOG_FILE informations from node-db1 ```mysql> show master status```

```
create user 'replusr'@'%' identified by 'P4SSWORD';
grant replication slave on *.* to 'replusr'@'%';
flush privileges;

CHANGE MASTER TO MASTER_HOST='node-db1', MASTER_USER='replusr', MASTER_PASSWORD='P4SSWORD', MASTER_LOG_FILE='mariadb-bin.000009', MASTER_LOG_POS=768;
```
<br>

##### on node-db1
 get MASTER_LOG_POS and  MASTER_LOG_FILE informations from node-db2 ```mysql> show master status```
```
create user 'replusr'@'%' identified by 'P4SSWORD';
grant replication slave on *.* to 'replusr'@'%';
flush privileges;

CHANGE MASTER TO MASTER_HOST='node-db2', MASTER_USER='replusr', MASTER_PASSWORD='P4SSWORD', MASTER_LOG_FILE='mariadb-bin.000017', MASTER_LOG_POS=754;
```

#### show and check status
on both nodes ```show slave satus\G; show master status;``` 

The slave informations entries must be equalent to output from other node ```show master status``` 

<br>

###### the importmant entries:
```
...
(slave) Master_Log_File     = (master) File
(slave) Exec_Master_Log_Pos = (master) Position
(slave) Read_Master_Log_Pos = (master) Position
...
```
<br>

###### status script for both nodes to compare informations

mysql_slave_status.sh

```
#! /bin/sh
PW=P4SWORD
DBUSER=DB-USER

echo -n "\n\n" $(hostname -f) "\n\n"
echo -n "SLAVE STATUS qualent to node-db1 master status \n"
mysql -u $DBUSER -p$PW -e "show slave status\G" | grep -E -i "Master_Log_File|Exec_Master_Log_Pos|Read_Master_Log_Pos|Err"

echo -n "MASTER STATUS\n"
mysql -u $DBUSER -p$PW -e "show master status\G"


```

<br>

##### compare and check status from both nodes
the script above is needed on both nodes

##### check from node-db1 

replication_status.sh

```
#! /bin/sh

    PW=P4SSWORD
DBUSER=DB-USER

remoteSlave=$(ssh -p22 node-db2 /home/user/mysql_slave_status.sh | grep -E -i "Master_Log_File|Exec_Master_Log_Pos" | awk '{print $2}'| uniq )
localMaster=$(mysql -u $DBUSER -p$PW -e "show master status\G" | grep -E "mariadb|Position" | awk '{print $2}')

echo -n "REPLICATION STATUS IS:\n"
if [ "$localMaster" == "$remoteSlave" ]; then echo "OK"; else echo "NOT OK";fi

echo -n "\n";
echo -n "remote Slave: "$remoteSlave"\n";
echo -n "local Master: "$localMaster"\n";

```
##### oneliner - replication status checker
```
PW=P4SSWORD; DBUSER=DB-USER; localMaster=$(mysql -u $DB-USER -p$PW -e "show master status\G" | grep -E "mariadb|Position" | awk '{print $2}'); remoteSlave=$(ssh -p22 node-db2 /home/user/mysql_slave_status.sh | grep -E -i "Master_Log_File|Exec_Master_Log_Pos" | awk '{print $2}'| uniq ); echo -e "\n Replication is" $(if [ "$localMaster" == "$remoteSlave" ]; then echo "OK"; else echo "NOT OK";fi); echo -e "\n" "local Master: "$localMaster " remote Slave: "$remoteSlave;
```
<br>

#### iptables - Allow specific ip to access mariaDB port (3306)
the following rule is only extension of existing iptables preconfigured rules. before this rule must be all input blocked.

```
IPT="/sbin/iptables"
$IPT -A INPUT -p tcp -s 10.10.0.40 --dport 3306 -m conntrack --ctstate NEW,ESTABLISHED -j ACCEPT
```


### full  /etc/mysql/my.cnf config for production

```mysql
[client]
port      = 3306
socket    = /var/run/mysqld/mysqld.sock

# Here is entries for some specific programs
# The following values assume you have at least 32M ram
# This was formally known as [safe_mysqld]. Both versions are currently parsed.

[mysqld_safe]
socket    = /var/run/mysqld/mysqld.sock
nice      = 0

[mysqld]

#
# * Basic Settings
#

user            = mysql
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
#bind-address		= 127.0.0.1

bind-address           = 0.0.0.0

#
# * Fine Tuning
#

max_connections         = 500
connect_timeout         = 5
wait_timeout            = 600
max_allowed_packet      = 16M
thread_cache_size       = 128
sort_buffer_size        = 4M
bulk_insert_buffer_size	= 16M
tmp_table_size          = 32M
max_heap_table_size     = 32M


#
# * MyISAM
#
# This replaces the startup script and checks MyISAM tables if needed
# the first time they are touched. On error, make copy and try a repair.

myisam_recover_options    = BACKUP
key_buffer_size           = 128M
#open-files-limit         = 2000
table_open_cache          = 400
myisam_sort_buffer_size   = 512M
concurrent_insert         = 2
read_buffer_size          = 2M
read_rnd_buffer_size      = 1M

#
# * Query Cache Configuration
#
# Cache only tiny result sets, so we can fit more in the query cache.

query_cache_limit		= 128K
query_cache_size		= 64M

# for more write intensive setups, set to DEMAND or OFF
#query_cache_type		= DEMAND
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

log_warnings		= 2

#
# Enable the slow query log to see queries with especially long duration
#slow_query_log[={0|1}]

slow_query_log_file	  = /var/log/mysql/mariadb-slow.log
long_query_time       = 10
#log_slow_rate_limit	= 1000
log_slow_verbosity	  = query_plan

#log-queries-not-using-indexes
#log_slow_admin_statements
#
# The following can be used as easy to replay backup logs or for replication.
# note: if you are setting up a replication slave, see README.Debian about
#       other settings you may need to change.

# MASTER REPLICATION

server-id                = 10
report_host              = node-db1
log_bin                  = /var/log/mysql/mariadb-bin
log_bin_index            = /var/log/mysql/mariadb-bin.index
relay_log                = /var/log/mysql/relay-bin
relay_log_index          = /var/log/mysql/relay-bin.index
# replicate-do-db        = testdb
auto_increment_increment = 5
auto_increment_offset    = 1


#
# If applications support it, this stricter sql_mode prevents some
# mistakes like inserting invalid dates etc.
#sql_mode		= NO_ENGINE_SUBSTITUTION,TRADITIONAL
#
# * InnoDB
#
# InnoDB is enabled by default with a 10MB datafile in /var/lib/mysql/.
# Read the manual for more InnoDB related options. There are many!
default_storage_engine	= InnoDB
# you can't just change log file size, requires special procedure
#innodb_log_file_size	= 50M

innodb_buffer_pool_size	= 256M
innodb_log_buffer_size	= 8M
innodb_file_per_table   = 1
innodb_open_files       = 400
innodb_io_capacity	    = 400
innodb_flush_method	    = O_DIRECT


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
max_allowed_packet	= 16M

[mysql]
#no-auto-rehash	# faster start of mysql but no tab completion

[isamchk]
key_buffer		    = 16M

#
# * IMPORTANT: Additional settings that can override those from this file!
#   The files must end with '.cnf', otherwise they'll be ignored.
#
!includedir /etc/mysql/conf.d/

```
<br>


useful links:

[MariaDB(MySQL) Master-Master Replication | Marko Sutic's Database Blog](http://msutic.blogspot.com/2015/02/mariadbmysql-master-master-replication.html)

