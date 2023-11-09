#!/usr/bin/env python3

# Author: Clemens Schwaighofer
# Description: PgBouncer stats

# have a .pgpass in $HOME for zabbix user with the below lines
# localhost:6432:pgbouncer:<USER>:<PASSWORD>
# 127.0.0.1:6432:pgbouncer:<USER>:<PASSWORD>

import sys
import json
import os
import configparser
import subprocess

dbname = 'pgbouncer'
hostname = ''
port = ''
username = ''
password = ''
file_pg_pass = os.path.join(os.path.expanduser('~'), '.pgpass')
file_pgbouncer_ini = '/etc/pgbouncer/pgbouncer.ini'
# get either ~/.pgpass OR /etc/pgbouncer/pgbouncer.ini, else abort with "ZBX_NOTSUPPORTED"
if os.path.isfile(file_pg_pass) and os.access(file_pg_pass, os.R_OK):
    with open(file_pg_pass, 'r') as fp:
        for line in fp.readlines():
            if ':pgbouncer:' in line and not username:
                entries = line.split(':')
                hostname = entries[0]
                port = entries[1]
                username = entries[3]
                password = entries[4].strip()
elif os.path.isfile(file_pgbouncer_ini) and os.access(file_pgbouncer_ini, os.R_OK):
    config = configparser.ConfigParser()
    config.read(file_pgbouncer_ini)
    settings = dict(config['pgbouncer'])
    hostname = settings['listen_addr']
    if hostname == '*':
        hostname = '127.0.0.1'
    port = settings['listen_port']
    # note we remove "postgres" user from this list and use the first we find?
    username = settings['stats_users'].replace(' ', '').replace('postgres', '').split(',')[0]
    if not username:
        username = 'pgbouncer'
else:
    print("ZBX_NOTSUPPORTED: Failed to get any pgbouncer connect info. .pgpass in zabbix user home dir?")
    sys.exit()

# if we have argument 1 as discovery we discover
sql_commands = 'show stats; show pools; show lists; show mem; show state; show version;'
discovery = False
if len(sys.argv) > 1 and sys.argv[1] == 'discovery':
    discovery = True
    sql_commands = 'show pools;'

# Check=True to throw erros
try:
    psql_command = subprocess.Popen(
        [
            'psql',
            '-qAXe',
            '-F:',
            '--pset', 'footer=off',
            '-h', f'{hostname}',
            '-p', f'{port}',
            '-U', f'{username}',
            f'{dbname}'
        ],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True
    )
except Exception as e:
    print(f"ZBX_NOTSUPPORTED: Could not prepare psql command, psql not installed or not in path? {e}")
    sys.exit()
output = ''
try:
    output, error = psql_command.communicate(sql_commands, timeout=10)
except subprocess.TimeoutExpired:
    psql_command.kill()
    print("ZBX_NOTSUPPORTED: Command timed out")
    sys.exit()
except Exception as e:
    print(f"ZBX_NOTSUPPORTED: Failed to communicate with psql subprocess: {e}")

pgbouncer_commands = {
    'show stats;': 'matrix',
    'show pools;': 'matrix',
    'show lists;': 'lines',
    'show mem;': 'matrix',
    'show state;': 'lines',
    'show version;': 'lines',
}

# run discovery
    # just colelct pool data and exist
if discovery is True:
    next_header = False
    pgbouncer_pool_list = {
        'data': []
    }
    for line in output.split("\n"):
        line = line.strip()
        # ignore first line command
        # ignore second line header
        # ignore all with pgbouncer:
        # get only first entry
        if line in pgbouncer_commands:
            next_header = True
            continue
        if next_header is True:
            next_header = False
            continue
        if line == '':
            continue
        if line.find('pgbouncer:') != -1:
            continue
        entries = line.split(':')
        pgbouncer_pool_list['data'].append({'{#POOLNAME}': entries[0]})
    print(f"{json.dumps(pgbouncer_pool_list, indent = 4)}")
    sys.exit();

# in which set to write total stats
pgbouncer_total = {
    "databases": "general",
    "users": "general",
    "peers": "general",
    "pools": "general",
    "peer_pools":"general",
    "free_clients": "clients",
    "used_clients": "clients",
    "login_clients": "clients",
    "free_servers": "servers",
    "used_servers": "servers",
    "dns_names": "dns",
    "dns_zones": "dns",
    "dns_queries": "dns",
    "dns_pending":"dns",
    # this is not from list but sum of all pools
    "avg_xact_count": "avg",
    "avg_query_count": "avg",
    "avg_recv": "avg",
    "avg_sent": "avg",
    "avg_xact_time": "avg",
    "avg_query_time": "avg",
    "avg_wait_time": "avg",
}

pgbouncer_total_sum = {
    "avg_xact_count": 0,
    "avg_query_count": 0,
    "avg_recv": 0,
    "avg_sent": 0,
    "avg_xact_time": 0,
    "avg_query_time": 0,
    "avg_wait_time": 0,
}

pgbouncer_stats = {
    "database": {},
    "total": {
        "general": {},
        "clients": {},
        "servers": {},
        "dns": {},
        "avg": {},
    },
    "mem": {},
    "state": {
        "active": -1,
        "paused": -1,
        "suspended": -1
    },
    "version": "",
}

header = []
next_header = False
wrote_data = False
current_command = ''
# for line in sys.stdin.readlines():
for line in output.split("\n"):
    line = line.strip()
    # print(f"=> Line: {line}")
    if line in pgbouncer_commands:
        next_header = True
        header = []
        # no data written -> write 0 data?
        current_command = line
        # total block, also add the pgbouncer total sum data
        if current_command == 'show lists;':
            for [key, value] in pgbouncer_total_sum.items():
                pgbouncer_stats['total']['avg'][key] = value
        continue
    if next_header is True:
        next_header = False
        # position build header
        for _header in line.split(':'):
            header.append(_header)
        continue
    wrote_data = True
    # skip empty lines
    if line == '':
        continue
    # skip lines with pgbouncer user or db
    if line.find('pgbouncer:') != -1:
        continue
    # split
    entries = line.split(':')
    if current_command == 'show stats;':
        # first setter, database is setter, rest is data sets in header
        if entries[0] not in pgbouncer_stats['database']:
            pgbouncer_stats['database'][entries[0]] = {}
        pgbouncer_stats['database'][entries[0]]['stats'] = {}
        for i in range(1, len(entries)):
            if header[i].startswith('total_'):
                continue;
            pgbouncer_stats['database'][entries[0]]['stats'][header[i]] = int(entries[i])
            pgbouncer_total_sum[header[i]] += int(entries[i])
    elif current_command == 'show pools;':
        if entries[0] not in pgbouncer_stats['database']:
            pgbouncer_stats['database'][entries[0]] = {}
        pgbouncer_stats['database'][entries[0]]['pools'] = {}
        for i in range(2, len(entries)):
            # unless poolmode -> all int
            if header[i] == 'pool_mode':
                value = entries[i]
            else:
                value = int(entries[i]);
            pgbouncer_stats['database'][entries[0]]['pools'][header[i]] = value
    elif current_command == 'show lists;':
        # total data
        if entries[0] not in pgbouncer_total:
            group = 'general'
        else:
            group = pgbouncer_total[entries[0]]
        # print(f"LIST, Group: {group}");
        pgbouncer_stats['total'][group][entries[0]] = entries[1];
    elif current_command == 'show mem;':
        # skip entry for now, so we store as is
        for i in range(1, len(entries)):
            if entries[0] not in pgbouncer_stats['mem']:
                pgbouncer_stats['mem'][entries[0]] = {}
            pgbouncer_stats['mem'][entries[0]][header[i]] = entries[i]
    elif current_command == 'show state;':
        # convert yes: 1, no: 0
        pgbouncer_stats['state'][entries[0]] = 1 if entries[1] == 'yes' else 0
    elif current_command == 'show version;':
        # just version string
        pgbouncer_stats['version'] = entries[0]

print(f"{json.dumps(pgbouncer_stats, indent = 4)}")

# __END__
