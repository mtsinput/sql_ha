#!/bin/bash

set -e

# if service discovery was activated, we overwrite the BACKEND_SERVER_LIST with the
# results of DNS service lookup
if [ -n "$DB_SERVICE_NAME" ]; then
  BACKEND_SERVER_LIST=`getent hosts tasks.$DB_SERVICE_NAME|awk '{print $1}'|tr '\n' ' '`
fi

# We break our IP list into array
IFS=', ' read -r -a backend_servers <<< "$BACKEND_SERVER_LIST"


config_file="/etc/maxscale.cnf"

# We start config file creation

cat <<EOF > $config_file
[maxscale]
admin_secure_gui=false
threads=auto
admin_host=0.0.0.0

[Galera-Service]
type=service
router=readconnroute
router_options=synced
targets=${BACKEND_SERVER_LIST// /,}
connection_timeout=$CONNECTION_TIMEOUT
user=$MAX_USER
password=$MAX_PASS
enable_root_user=$ENABLE_ROOT_USER

[Galera-Listener]
type=listener
service=Galera-Service
protocol=mariadbclient
port=$ROUTER_PORT

[Splitter-Service]
type=service
router=readwritesplit
targets=${BACKEND_SERVER_LIST// /,}
connection_timeout=$CONNECTION_TIMEOUT
user=$MAX_USER
password=$MAX_PASS
enable_root_user=$ENABLE_ROOT_USER
use_sql_variables_in=$USE_SQL_VARIABLES_IN

[Splitter-Listener]
type=listener
service=Splitter-Service
protocol=mariadbclient
port=$SPLITTER_PORT

[Galera-Monitor]
type=monitor
module=galeramon
servers=${BACKEND_SERVER_LIST// /,}
disable_master_failback=false
user=$MAX_USER
password=$MAX_PASS
# Start the Server block
EOF

# add the [server] block
for i in ${!backend_servers[@]}; do
cat <<EOF >> $config_file
[${backend_servers[$i]}]
type=server
address=${backend_servers[$i]}
port=$BACKEND_SERVER_PORT
persistpoolmax=$PERSIST_POOLMAX
persistmaxtime=$PERSIST_MAXTIME
EOF

done


exec "$@"

set -m

/usr/bin/maxscale --nodaemon --user=maxscale --log=stdout &

sleep 4

/usr/bin/maxctrl --user=admin --password=mariadb create user "tmp_maxscale_user" "tmp_password" --type=admin
/usr/bin/maxctrl --user=tmp_maxscale_user --password=tmp_password destroy user "admin"
/usr/bin/maxctrl --user=tmp_maxscale_user --password=tmp_password create user $REST_USER $REST_PASS --type=admin
/usr/bin/maxctrl --user=$REST_USER --password=$REST_PASS destroy user "tmp_maxscale_user"

fg %1

