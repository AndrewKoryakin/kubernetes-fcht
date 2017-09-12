#!/bin/bash

cat $1 | clickhouse-client --host="${CLICKHOUSE_HOST}" --port="${CLICKHOUSE_PORT}" --user="${CLICKHOUSE_USER}" --database="${CLICKHOUSE_DB}"  --query="INSERT INTO ${K8S_LOG_TABLE} FORMAT JSONEachRow";
