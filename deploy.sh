#!/bin/bash

if [ -z "${NAMESPACE}" ]; then
    NAMESPACE=kube-logging
fi

kubectl create namespace "$NAMESPACE"

kctl() {
    kubectl --namespace "$NAMESPACE" "$@"
}

echo "Deploying fluentd"
kctl apply -f manifests/fluentd

echo "Deploying clickhouse"
kctl apply -f manifests/clickhouse

echo "Deploying ingress"
kctl apply -f manifests/ingress
