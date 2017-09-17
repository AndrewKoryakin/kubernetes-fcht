#!/bin/bash
clickhouse-client --host=${CLICKHOUSE_SERVER} --port=${CLICKHOUSE_PORT} --user=${CLICKHOUSE_USER} --password=${CLICKHOUSE_PASS} --query="CREATE DATABASE ${CLICKHOUSE_DB};"
clickhouse-client --host=${CLICKHOUSE_SERVER} --port=${CLICKHOUSE_PORT} --user=${CLICKHOUSE_USER} --password=${CLICKHOUSE_PASS} --database=${CLICKHOUSE_DB} --query="CREATE TABLE ${CLICKHOUSE_DB}.${K8S_LOGS_TABLE} (date Date MATERIALIZED toDate(timestamp), timestamp DateTime, nsec UInt32, namespace String, tag String, labels Nested (key String, value String), host String, pod_name String, container_name String, stream String, logs Nested (key String, value String) ) ENGINE = MergeTree(date, (timestamp, nsec), 32768);"
