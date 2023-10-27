#!/usr/bin/env bash
# Author:	Lesovsky A.V.
# Description:	Pgbouncer pools stats
# $1 - param_name, $2 - pool_name

# have a .pgpass in $HOME for zabbix user with the below lines
# localhost:6432:pgbouncer:zbx_monitor:<PASSWORD>
# 127.0.0.1:6432:pgbouncer:zbx_monitor:<PASSWORD>

if [ -f ~/.pgpass ];
then
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

if [ '*' = "$hostname" ]; then hostname="127.0.0.1"; fi

conn_param="-qAtX -F: -h $hostname -p $port -U $username $dbname"

# pgbouncer 1.18

# stats
# ───┬──[ RECORD 1 ]─────┼──────────
#  1 │ database          │
#  2 │ total_xact_count  │
#  3 │ total_query_count │
#  4 │ total_received    │
#  5 │ total_sent        │
#  6 │ total_xact_time   │
#  7 │ total_query_time  │
#  8 │ total_wait_time   │
#  9 │ avg_xact_count    │
# 10 │ avg_query_count   │ avg_req, total_avg_req
# 11 │ avg_recv          │ avg_recv, total_avg_recv
# 12 │ avg_sent          │ avg_sent, total_avg_sent
# 13 │ avg_xact_time     │
# 14 │ avg_query_time    │ avg_query, total_avg_query
# 15 │ avg_wait_time     │

# pool
# ───┬──[ RECORD 1 ]─────────┼────────────
#  1 │ database              │
#  2 │ user                  │
#  3 │ cl_active             │ cl_active
#  4 │ cl_waiting            │ cl_waiting
#  5 │ cl_active_cancel_req  │
#  6 │ cl_waiting_cancel_req │
#  7 │ sv_active             │ sv_active
#  8 │ sv_active_cancel      │
#  9 │ sv_being_canceled     │
# 10 │ sv_idle               │ sv_idle
# 11 │ sv_used               │ sv_used
# 12 │ sv_tested             │ sv_tested
# 13 │ sv_login              │ sv_login
# 14 │ maxwait               │ maxwait
# 15 │ maxwait_us            │ maxwait_us
# 16 │ pool_mode             │ poolmode

# lists
#      list      │ items │ used
# ───────────────┼───────┼────────────
#  databases     │     4 │
#  users         │     6 │
#  pools         │     2 │
#  free_clients  │    28 │ free_clients
#  used_clients  │    22 │ used_clients
#  login_clients │     0 │ login_clients
#  free_servers  │    45 │ free_servers
#  used_servers  │     5 │ used_servers
#  dns_names     │     1 │
#  dns_zones     │     0 │
#  dns_queries   │    -5 │
#  dns_pending   │     0 │

# Not used:
#> show mem;
#      name     │ size │ used │ free │ memtotal
# ──────────────┼──────┼──────┼──────┼──────────
#  user_cache   │ 2312 │    7 │   43 │   115600
#  db_cache     │  208 │    4 │   74 │    16224
#  pool_cache   │  552 │    2 │   48 │    27600
#  server_cache │  608 │    5 │   45 │    30400
#  client_cache │  608 │   22 │   28 │    30400
#  iobuf_cache  │ 4112 │    1 │   49 │   205600

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
