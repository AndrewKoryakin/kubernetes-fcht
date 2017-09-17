#!/bin/bash

if [ -z "${NAMESPACE}" ]; then
    NAMESPACE=kube-logging
fi

kubectl create namespace "$NAMESPACE"

kctl() {
    kubectl --namespace "$NAMESPACE" "$@"
}

if [ -n "$STORAGE_NAMESPACE" ] ;
then
  STORAGECLASS_USER_SECRET_NAME=$(kctl get storageclass $STORAGE_CLASS_NAME -o json | jq '.parameters.userSecretName' | tr -d '"')
  STORAGECLASS_USER_SECRET_VALUE=$(kubectl -n $STORAGE_NAMESPACE get secret $STORAGECLASS_USER_SECRET_NAME -o json | jq '.data.key' | tr -d '"')
  sed -i -e "s/##STORAGECLASS_USER_SECRET_NAME##/$STORAGECLASS_USER_SECRE_NAME/" manifests/clickhouse/storage_secret.yaml
  sed -i -e "s/##STORAGECLASS_USER_SECRET_VALUE##/$STORAGECLASS_USER_SECRET_VALUE/" manifests/clickhouse/storage_secret.yaml
  echo "Deploying storageclass secret"
  kctl apply -f manifests/clickhouse/storage_secret.yaml
fi

echo "Deploying Clickhouse"
kctl apply -f manifests/clickhouse/clickhouse.yaml
echo "Waiting for clickhouse up"
until kctl get pod | grep clickhouse-server | grep Running > /dev/null 2>&1; do sleep 1; printf "."; done

echo "Create database and table"
kctl exec $(kctl get pod | grep clickhouse-server | awk '{print $1}') /usr/local/bin/init.sh 

#echo "Deploying fluentd"
#kctl apply -f manifests/fluentd

#echo "Deploying ingress"
#kctl apply -f manifests/ingress
