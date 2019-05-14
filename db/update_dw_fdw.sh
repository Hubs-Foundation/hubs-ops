#!/usr/bin/env bash

if [[ -z "$1" ]]; then
  echo -e "
Usage: update_dw_fdw.sh <ret-dw-host> <ret-dw-port> <ret-dw-user> <ret-dw-remote-user-password> <ret-dw-dbname> <ret-db-host> <ret-db-port> <ret-db-dwuser> <ret-db-dwuser-password> <ret-db-dbname>

Updates the FDW connections in the dw databse to point to the specified ret db.
"
  exit 1
fi

RET_DW_HOST=$1
RET_DW_PORT=$2
RET_DW_USER=$3
RET_DW_REMOTE_USER_PASSWORD=$4
RET_DW_DBNAME=$5
RET_DB_HOST=$6
RET_DB_PORT=$7
RET_DB_DWUSER=$8
RET_DB_DWUSER_PASSWORD=$9
RET_DB_DBNAME=${10}


psql -U "$RET_DW_USER" -h "$RET_DW_HOST" -p "$RET_DW_PORT" $RET_DW_DBNAME << EOF
set search_path=public;
create extension if not exists postgres_fdw;
drop server if exists ret_db cascade;
create server ret_db foreign data wrapper postgres_fdw options (host '$RET_DB_HOST', port '$RET_DB_PORT', dbname '$RET_DB_DBNAME');
DO
\$do$
BEGIN
   IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE  rolname = 'ret_dw_remote') THEN
      CREATE ROLE ret_dw_remote LOGIN PASSWORD '$RET_DW_REMOTE_USER_PASSWORD';
   ELSE
      ALTER ROLE ret_dw_remote PASSWORD '$RET_DW_REMOTE_USER_PASSWORD';
   END IF;
END
\$do$;
create user mapping for ret_dw_remote server ret_db options (user '$RET_DB_DWUSER', password '$RET_DB_DWUSER_PASSWORD');
drop schema if exists ret_dw;
create schema ret_dw;
grant usage on schema ret_dw to ret_dw_remote;
grant create on schema ret_dw to ret_dw_remote;
grant usage on foreign server ret_db to ret_dw_remote;
set role ret_dw_remote;
import foreign schema ret0_dw from server ret_db into ret_dw;
grant select on all tables in schema ret_dw to ret_dw_remote; 
EOF
