#!/bin/sh

LANG=C
export LANG

PGHOME=/usr/pgsql-9.3
PATH=$PGHOME/bin:$PATH
PGPORT=15432
export PGHOME PATH PGPORT

CHECKSUM=$1
TXN=$2
SF=$3
COUNT=$4

if [ -z $COUNT ]; then
    echo "Usage: $0 <CHECKSUM> <TXN> <SF> <LOOPCOUNT>"
    exit
fi

pg_ctl -D /disk/disk1/pgsql/checksum/data stop

rm -rf /disk/disk1/pgsql/checksum/data

mkdir -p /disk/disk1/pgsql/checksum/data

echo initdb --no-locale -E UTF-8 -D /disk/disk1/pgsql/checksum/data ${CHECKSUM}
initdb --no-locale -E UTF-8 -D /disk/disk1/pgsql/checksum/data ${CHECKSUM}

cp postgresql.conf /disk/disk1/pgsql/checksum/data

pg_ctl -w -D /disk/disk1/pgsql/checksum/data start

createdb testdb
pgbench -i -s $SF testdb
psql -c 'show shared_buffers' testdb
psql -c 'select pg_size_pretty(pg_database_size(current_database()))' testdb

i=0
while [ 1 ];
  do psql -c checkpoint testdb
     psql -c 'select pg_stat_reset()' testdb
#     psql -c "select pg_stat_reset_shared('bgwriter')" testdb

     echo "Running pgbench..."
     pgbench -S -c 8 -t $TXN testdb

     psql testdb <<EOF
\x
select * from pg_stat_bgwriter;
select * from pg_stat_database where datname = current_database();
EOF
  i=`expr $i + 1`
  if [ $i -gt $COUNT ]; then
    echo "Repeated $i times. Exit"
    break;
  else
    echo "Repeating."
  fi;
done;

pg_ctl -w -D /disk/disk1/pgsql/checksum/data stop
