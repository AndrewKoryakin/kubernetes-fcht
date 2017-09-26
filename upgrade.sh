#!/bin/bash

set -e
if [ -z "${NAMESPACE}" ]; then
    NAMESPACE=kube-logging
fi

if [ ! "$(kubectl get ns ${NAMESPACE} -o name)" ]; then
  echo "Not found namespace ${NAMESPACE}"
  exit 1
fi

kctl() {
    kubectl --namespace "$NAMESPACE" "$@"
}

if [ "$(kubectl -n kube-logging get secret -l storage=clickhouse -o name)" ] ; then
  echo "Deploying storageclass secret"
  kctl apply -f manifests/clickhouse/storage_secret.yaml
fi

echo "Upgrade Clickhouse"
kctl apply -f manifests/clickhouse/clickhouse-configmap.yaml
kctl apply -f manifests/clickhouse/clickhouse.yaml

echo "Upgrade fluentd"
kctl apply -f manifests/fluentd

echo "Upgrade tabbix"
kctl apply -f manifests/tabix

echo "Upgrade ingress"
kctl apply -f manifests/ingress
