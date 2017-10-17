#!/bin/bash
TABLE=$(date +%Y%m%d)
# Create database
clickhouse-client --host=127.0.0.1 --port=${CLICKHOUSE_PORT} --user=${CLICKHOUSE_USER} --password=${CLICKHOUSE_PASS} --query="CREATE DATABASE ${CLICKHOUSE_DB};"
# Create daily logs table
clickhouse-client --host=127.0.0.1 --port=${CLICKHOUSE_PORT} --user=${CLICKHOUSE_USER} --password=${CLICKHOUSE_PASS} --database=${CLICKHOUSE_DB} --query="CREATE TABLE ${CLICKHOUSE_DB}.logs${TABLE} (date Date MATERIALIZED toDate(timestamp), timestamp DateTime, nsec UInt32, namespace String, host String, pod_name String, container_name String, stream String, string_fields Nested (names String, values String), number_fields Nested (names String, values Float64), boolean_fields Nested (names String, values Float64), null_fields Nested (names String)) ENGINE = MergeTree(date, (timestamp, nsec), 32768);"
# Create logs Merge table
clickhouse-client --host=127.0.0.1 --port=${CLICKHOUSE_PORT} --user=${CLICKHOUSE_USER} --password=${CLICKHOUSE_PASS} --database=${CLICKHOUSE_DB} --query="CREATE TABLE ${CLICKHOUSE_DB}.${K8S_LOGS_TABLE} (date Date MATERIALIZED toDate(timestamp), timestamp DateTime, nsec UInt32, namespace String, host String, pod_name String, container_name String, stream String, string_fields Nested (names String, values String), number_fields Nested (names String, value Float64), boolean_fields Nested (names String, values Float64), null_fields Nested (name String)) ENGINE = Merge(${CLICKHOUSE_DB}, '^logs');"
# Create system logs table
clickhouse-client --host=127.0.0.1 --port=${CLICKHOUSE_PORT} --user=${CLICKHOUSE_USER} --password=${CLICKHOUSE_PASS} --database=${CLICKHOUSE_DB} --query="CREATE TABLE ${CLICKHOUSE_DB}.system_logs (date Date MATERIALIZED toDate(timestamp), timestamp DateTime, nsec UInt32, tag String, logs Nested (key String, value String)) ENGINE = MergeTree(date, (timestamp, nsec), 32768);"
