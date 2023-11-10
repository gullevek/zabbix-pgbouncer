# PgBouncer monitoring

Original: <https://github.com/lesovsky/zabbix-extensions/tree/master/files/pgbouncer>

Changes:
Discover Service uses central call to call all stats in one set which are returned as JSON and then post processed

## How to setup

- must have a user with a password setup to access the pgbouncer stats
- zabbix user must have a home directory

### Confirm that zabbix user had a homedirectory

```sh
cat /etc/passwd | grep zabbix | cut -d ":" -f6
```

This should return something like `/var/lib/zabbix`. If not the zabbix user needs a home directory set

### Add .pgpass to the zabbix home directory

```ini
127.0.0.1:6432:pgbouncer:<User>:<Password>
```

The 'User' must be in the list of 'stats_users' in the `pgbouncer.ini`

Set the owner `.pgass` file to 'zabbix' and the chmod has to be at leat 600 or lower

```sh
chown zabbix: /var/lib/zabbix/.pgpass
chmod 600 /var/lib/zabbix/.pgpass
```

Confirm that the settings are correct with

```sh
sudo -u zabbix psql -U <User> -p 6432 -h 127.0.0.1 pgbouncer
```

### File copy

- copy 'pgbouncer.stat.py' to '/etc/zabbix/scripts/'
- copy 'userparameter_pgbouncer.conf' to '/etc/zabbix/zabbix_agentd.conf.d/'

and then restart the zabbix agent

Import the 'pgbouncer-extended-template.xml' in the Zabbix Template directory

Configuration -> Templates -> Import (top upper right corner)

#### Confirm stats scripts work

```sh
sudo -u zabbix /etc/zabbix/scripts/pgbouncer.stat.py discovery
```

should print out the list of pools currently available

### Final setup

Add the template 'Template App PGBouncer Extended' to the host where needed.
No further settings are needed.

## PgBouncer stats comments

```sql
SHOW HELP|CONFIG|DATABASES|POOLS|CLIENTS|SERVERS|USERS|VERSION
SHOW PEERS|PEER_POOLS
SHOW FDS|SOCKETS|ACTIVE_SOCKETS|LISTS|MEM|STATE
SHOW DNS_HOSTS|DNS_ZONES
SHOW STATS|STATS_TOTALS|STATS_AVERAGES|TOTALS
```

## What is used

`;stats_period = 60` for status update period (in seconds)

Used:

- stats
- pools
- lists
- state: for active/etc check

Not used:

- databases (for various base settings), but only avaiable on active connection -> not used
- mem: subject to change -> not used

ignore `STATS_TOTALS`, `STATS_AVERAGES` and `TOTALS` as they have "pgbouncer" table inside, we do not want that

### command line call

note that in zabbix contex and already setup `sudo -u zabbix` can be used to not have to input the password

`psql -qAX -F: --pset='footer=off' -h localhost -p 6432 -U zbx_monitor pgbouncer -c "show stats"`

Sample output

```txt
database:total_xact_count:total_query_count:total_received:total_sent:total_xact_time:total_query_time:total_wait_time:avg_xact_count:avg_query_count:avg_recv:avg_sent:avg_xact_time:avg_query_time:avg_wait_time
clemens:0:0:0:534:0:0:22348:0:0:0:0:0:0:0
pgbouncer:4:4:0:0:0:0:0:0:0:0:0:0:0:0
```

### combined call

note that in zabbix contex and already setup `sudo -u zabbix` can be used to not have to input the password

We remove all "pgbouncer:" database or user entries from this. We also add the queries so we know where to change the output group. First line after command (show ...; is headline)

```sh
echo "show stats; show pools; show lists; show mem; show state; show version;" |
psql -qAXe -F: --pset='footer=off' -h localhost -p 6432 -U zbx_monitor pgbouncer |
grep -v pgbouncer:
```

stats/ppols are per line databse and total sum up set

The rest are 1:1 mappings

Sample output:

```txt
show stats;
database:total_xact_count:total_query_count:total_received:total_sent:total_xact_time:total_query_time:total_wait_time:avg_xact_count:avg_query_count:avg_recv:avg_sent:avg_xact_time:avg_query_time:avg_wait_time
clemens:0:0:0:534:0:0:22348:0:0:0:0:0:0:0
show pools;
database:user:cl_active:cl_waiting:cl_active_cancel_req:cl_waiting_cancel_req:sv_active:sv_active_cancel:sv_being_canceled:sv_idle:sv_used:sv_tested:sv_login:maxwait:maxwait_us:pool_mode
clemens:clemens:0:0:0:0:0:0:0:0:0:0:0:0:0:transaction
show lists;
list:items
databases:1
users:2
peers:0
pools:3
peer_pools:0
free_clients:48
used_clients:2
login_clients:0
free_servers:50
used_servers:0
dns_names:0
dns_zones:0
dns_queries:0
dns_pending:0
show mem;
name:size:used:free:memtotal
user_cache:2312:4:46:115600
db_cache:232:2:68:16240
peer_cache:232:0:0:0
peer_pool_cache:592:0:0:0
pool_cache:592:3:47:29600
outstanding_request_cache:40:0:0:0
server_cache:688:0:50:34400
client_cache:688:2:48:34400
iobuf_cache:4112:1:49:205600
var_list_cache:48:5:336:16368
server_prepared_statement_cache:72:0:0:0
show state;
key:value
active:yes
paused:no
suspended:no
show version;
version
PgBouncer 1.21.0
```

## SHOW info, PgBouncer 1.21

`=# show stats;`

```sql
───┬──[ RECORD 1 ]─────┼──────────
 1 │ database          │
 2 │ total_xact_count  │
 3 │ total_query_count │
 4 │ total_received    │
 5 │ total_sent        │
 6 │ total_xact_time   │
 7 │ total_query_time  │
 8 │ total_wait_time   │
 9 │ avg_xact_count    │
10 │ avg_query_count   │ avg_req, total_avg_req
11 │ avg_recv          │ avg_recv, total_avg_recv
12 │ avg_sent          │ avg_sent, total_avg_sent
13 │ avg_xact_time     │
14 │ avg_query_time    │ avg_query, total_avg_query
15 │ avg_wait_time     │
```

`=# show pool;`

```sql
───┬──[ RECORD 1 ]─────────┼────────────
 1 │ database              │
 2 │ user                  │
 3 │ cl_active             │ cl_active
 4 │ cl_waiting            │ cl_waiting
 5 │ cl_active_cancel_req  │
 6 │ cl_waiting_cancel_req │
 7 │ sv_active             │ sv_active
 8 │ sv_active_cancel      │
 9 │ sv_being_canceled     │
10 │ sv_idle               │ sv_idle
11 │ sv_used               │ sv_used
12 │ sv_tested             │ sv_tested
13 │ sv_login              │ sv_login
14 │ maxwait               │ maxwait
15 │ maxwait_us            │ maxwait_us
16 │ pool_mode             │ poolmode
```

`=# show lists;`

```sql
     list      │ items │ used
───────────────┼───────┼────────────
 databases     │     4 │
 users         │     6 │
 peers         │     0 │
 pools         │     2 │
 peer_pools    │     0 │
 free_clients  │    28 │ free_clients
 used_clients  │    22 │ used_clients
 login_clients │     0 │ login_clients
 free_servers  │    45 │ free_servers
 used_servers  │     5 │ used_servers
 dns_names     │     1 │
 dns_zones     │     0 │
 dns_queries   │    -5 │
 dns_pending   │     0 │
```

`=# show mem;`

```sql
              name               │ size │ used │ free │ memtotal
─────────────────────────────────┼──────┼──────┼──────┼──────────
 user_cache                      │ 2312 │    4 │   46 │   115600
 db_cache                        │  232 │    2 │   68 │    16240
 peer_cache                      │  232 │    0 │    0 │        0
 peer_pool_cache                 │  592 │    0 │    0 │        0
 pool_cache                      │  592 │    3 │   47 │    29600
 outstanding_request_cache       │   40 │    0 │    0 │        0
 server_cache                    │  688 │    0 │   50 │    34400
 client_cache                    │  688 │    1 │   49 │    34400
 iobuf_cache                     │ 4112 │    1 │   49 │   205600
 var_list_cache                  │   48 │    4 │  337 │    16368
 server_prepared_statement_cache │   72 │    0 │    0 │        0
```

`=# show state;`

```sql
    key    │ value
───────────┼───────
 active    │ yes
 paused    │ no
 suspended │ no
```

`=# show version;`

```sql
     version
──────────────────
 PgBouncer 1.21.0
```

## JSON layout

for pool and stats

```json
{
    "database": {
        "database:user": {
            "stats": {
                "avg_xact_count": 0,
                "avg_query_count": 0,
                "avg_recv": 0,
                "avg_sent": 0,
                "avg_xact_time": 0,
                "avg_query_time": 0,
                "avg_wait_time": 0
            },
            "pools": {
                "cl_active": 0,
                "cl_waiting": 0,
                "cl_active_cancel_req": 0,
                "cl_waiting_cancel_req": 0,
                "sv_active": 0,
                "sv_active_cancel": 0,
                "sv_being_canceled": 0,
                "sv_idle": 0,
                "sv_used": 0,
                "sv_tested": 0,
                "sv_login": 0,
                "maxwait": 0,
                "maxwait_us": 0,
                "pool_mode": ""
            }
        }
    },
    "total": {
        "general": {
            "databases": 0,
            "users": 0,
            "peers": 0,
            "pools": 0,
            "peer_pools": 0
        },
        "clients": {
            "free_clients": 0,
            "used_clients": 0,
            "login_clients": 0
        },
        "servers": {
            "free_servers": 0,
            "used_servers": 0
        },
        "dns": {
            "dns_names": 0,
            "dns_zones": 0,
            "dns_queries": 0,
            "dns_pending": 0
        },
        "avg": {
            "avg_xact_count": 0,
            "avg_query_count": 0,
            "avg_recv": 0,
            "avg_sent": 0,
            "avg_xact_time": 0,
            "avg_query_time": 0,
            "avg_wait_time": 0
        },
    },
    "mem": {},
    "state": {
        "active": 1,
        "paused": 0,
        "suspended": 0
    },
    "version": "PgBouncer 1.21.0",
}
```
