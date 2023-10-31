#!/usr/bin/env bash
# Author:	Lesovsky A.V.
# Description:	Pgbouncer pools stats
# $1 - param_name, $2 - pool_name

# have a .pgpass in $HOME for zabbix user with the below lines
# localhost:6432:pgbouncer:zbx_monitor:<PASSWORD>
# 127.0.0.1:6432:pgbouncer:zbx_monitor:<PASSWORD>

if [ -f ~/.pgpass ]; then
	username=$(head -n 1 ~/.pgpass |cut -d: -f4)
else
	username="postgres"
	# username="zbx_monitor"
fi

PSQL=$(which psql)
config='/etc/pgbouncer/pgbouncer.ini'
hostname=$(grep -w ^listen_addr $config |cut -d" " -f3 |cut -d, -f1)
port=6432
dbname="pgbouncer"
PARAM="$1"
# for stats: avg_* requests
db_name=$(echo $2 | cut -d: -f1);

if [ '*' = "$hostname" ]; then
	hostname="127.0.0.1";
fi

conn_param="-qAtX -F: --pset='footer=off' -h $hostname -p $port -U $username $dbname"

case "$PARAM" in
'avg_req' )
        $PSQL $conn_param -c "show stats" |grep -w $db_name |cut -d: -f10
;;
'avg_recv' )
        $PSQL $conn_param -c "show stats" |grep -w $db_name |cut -d: -f11
;;
'avg_sent' )
        $PSQL $conn_param -c "show stats" |grep -w $db_name |cut -d: -f12
;;
'avg_query' )
        $PSQL $conn_param -c "show stats" |grep -w $db_name |cut -d: -f14
;;
# POOLS
'cl_active' )
        $PSQL $conn_param -c "show pools" |grep -w $2 |cut -d: -f3
;;
'cl_waiting' )
        $PSQL $conn_param -c "show pools" |grep -w $2 |cut -d: -f4
;;
'sv_active' )
        $PSQL $conn_param -c "show pools" |grep -w $2 |cut -d: -f7
;;
'sv_idle' )
        $PSQL $conn_param -c "show pools" |grep -w $2 |cut -d: -f10
;;
'sv_used' )
        $PSQL $conn_param -c "show pools" |grep -w $2 |cut -d: -f11
;;
'sv_tested' )
        $PSQL $conn_param -c "show pools" |grep -w $2 |cut -d: -f12
;;
'sv_login' )
        $PSQL $conn_param -c "show pools" |grep -w $2 |cut -d: -f13
;;
'maxwait' )
        $PSQL $conn_param -c "show pools" |grep -w $2 |cut -d: -f14
;;
'maxwait_us' )
        $PSQL $conn_param -c "show pools" |grep -w $2 |cut -d: -f15
;;
'poolmode' )
        $PSQL $conn_param -c "show pools" |grep -w $2 |cut -d: -f16
;;
# LISTS
'free_clients' )
        $PSQL $conn_param -c "show lists" |grep -w free_clients |cut -d: -f2
;;
'used_clients' )
        $PSQL $conn_param -c "show lists" |grep -w used_clients |cut -d: -f2
;;
'login_clients' )
        $PSQL $conn_param -c "show lists" |grep -w login_clients |cut -d: -f2
;;
'free_servers' )
        $PSQL $conn_param -c "show lists" |grep -w free_servers |cut -d: -f2
;;
'used_servers' )
        $PSQL $conn_param -c "show lists" |grep -w used_servers |cut -d: -f2
;;
# TOTAL STATS
'total_avg_req' )
        $PSQL $conn_param -c "show stats" |cut -d: -f10 |awk '{ s += $1 } END { print s }'
;;
'total_avg_recv' )
        $PSQL $conn_param -c "show stats" |cut -d: -f11 |awk '{ s += $1 } END { print s }'
;;
'total_avg_sent' )
        $PSQL $conn_param -c "show stats" |cut -d: -f12 |awk '{ s += $1 } END { print s }'
;;
'total_avg_query' )
        $PSQL $conn_param -c "show stats" |cut -d: -f14 |awk -F: '{ s += $1 } END { print s }'
;;
* ) echo "ZBX_NOTSUPPORTED"; exit 1;;
esac
