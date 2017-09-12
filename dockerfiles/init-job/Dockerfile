FROM ubuntu:16.04

RUN echo 'http://repo.yandex.ru/clickhouse/xenial stable main' > /etc/apt/sources.list.d/clickhouse.list \
  && apt-get update \
  && apt-get -y install clickhouse-server-common clickhouse-client
