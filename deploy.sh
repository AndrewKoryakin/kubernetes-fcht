#!/bin/bash

set -e
if [ -z "${NAMESPACE}" ]; then
    NAMESPACE=kube-logging
fi

kubectl create namespace "$NAMESPACE"

kctl() {
    kubectl --namespace "$NAMESPACE" "$@"
}

if [ -n "$STORAGE_NAMESPACE" ] ;
then
  echo "Deploying storageclass secret"
  kctl apply -f manifests/clickhouse/storage_secret.yaml
fi

echo "Deploying Clickhouse"
kctl apply -f manifests/clickhouse/clickhouse-configmap.yaml
kctl apply -f manifests/clickhouse/clickhouse.yaml
echo "Waiting for clickhouse up"
until kctl get pod | grep clickhouse-server | grep Running > /dev/null 2>&1; do sleep 1; printf "."; done

echo "Create database and table"
kctl exec $(kctl get pod | grep clickhouse-server | awk '{print $1}') /usr/local/bin/init.sh 

echo "Deploying fluentd"
kctl apply -f manifests/fluentd

echo "Deploying fluentd"
kctl apply -f manifests/tabix

echo "Deploying ingress"
kctl apply -f manifests/ingress
