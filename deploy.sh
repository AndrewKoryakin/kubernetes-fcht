#!/bin/bash

if [ -z "${NAMESPACE}" ]; then
    NAMESPACE=kube-logging
fi

kubectl create namespace "$NAMESPACE"

kctl() {
    kubectl --namespace "$NAMESPACE" "$@"
}

echo "Deploying MoongoDB"
kctl apply -f manifests/mongo/mongodb.yaml
#echo "Deploying Clickhouse"
#kctl apply -f manifests/clickhouse/clickhouse.yaml
#echo "Init DB in Clickhouse"
#kctl apply -f manifests/clickhouse/init-job.yaml
#sleep 10

echo "Deploying fluentd"
kctl apply -f manifests/fluentd

echo "Deploying ingress"
kctl apply -f manifests/ingress
