#!/bin/bash

if [ ! "${NAMESPACE}" ]; then
    NAMESPACE=kube-logging
fi

kctl() {
    kubectl --namespace "$NAMESPACE" "$@"
}

kctl delete -f manifests/fluentd
kctl delete -f manifests/clickhouse
kctl delete -f manifests/ingress
