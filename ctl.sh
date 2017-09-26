#!/bin/bash

set -ex

! read -rd '' HELP_STRING <<"EOF"
Usage: ctl.sh [OPTION]... [-i|--install] KUBE_HOST
   or: ctl.sh [OPTION]...

Install FCHT (Fluentd, ClickHouse, Tabix) stack to Kubernetes cluster.

Mandatory arguments:
  -i, --install                install into 'kube-logging' namespace, override with '-n' option
  -u, --upgrade                upgrade existing installation, will reuse password and host names
  -d, --delete                 remove everything, including the namespace

Optional arguments:
  --clickhouse-pass            set clickhouse default user password
  --clickhouse-db              set clickhouse DB name for collecting logs
  --storage-class-name         name of the storage class
  --storage-size               storage size with optional IEC suffix
  --storage-namespace          set name of namespace from what copy secret

Optional arguments:
  -h, --help                   output this message
EOF

RANDOM_NUMBER=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 4 | head -n 1)
TMP_DIR="/tmp/fcht-ctl-$RANDOM_NUMBER"
WORKDIR="$TMP_DIR/kubernetes-fcht"
DEPLOY_SCRIPT="./deploy.sh"
TEARDOWN_SCRIPT="./teardown.sh"

MODE=""
USER=admin
NAMESPACE="kube-logging"
FIRST_INSTALL="true"
STORAGE_CLASS_NAME="rbd"
STORAGE_SIZE="20Gi"
CLICKHOUSE_PASS="default"
CLICKHOUSE_DB="logs"
K8S_LOGS_TABLE="logs"

TEMP=$(getopt -o i,u,d,h --long help,install,upgrade,delete,storage-class-name:,storage-size:,clickhouse-pass:,clickhouse-db:,storage-namespace: \
             -n 'ctl' -- "$@")

eval set -- "$TEMP"

while true; do
  case "$1" in
    -i | --install )
      MODE=install; shift ;;
    -u | --upgrade )
      MODE=upgrade; shift ;;
    -d | --delete )
      MODE=delete; shift ;;
    --storage-class-name )
      STORAGE_CLASS_NAME="$2"; shift 2;;
    --storage-size )
      STORAGE_SIZE="$2"; shift 2;;
    --clickhouse-pass )
      CLICKHOUSE_PASS="$2"; shift 2;;
    --clickhouse-db )
      CLICKHOUSE_DB="$2"; shift 2;;
    --storage-namespace )
      STORAGE_NAMESPACE="$2"; shift 2;;
    -h | --help )
      echo "$HELP_STRING"; exit 0 ;;
    -- )
      shift; break ;;
    * )
      break ;;
  esac
done

if [ ! "$MODE" ]; then echo "Mode of operation not provided. Use '-h' to print proper usage."; exit 1; fi

type curl >/dev/null 2>&1 || { echo >&2 "I require curl but it's not installed.  Aborting."; exit 1; }
type base64 >/dev/null 2>&1 || { echo >&2 "I require base64 but it's not installed.  Aborting."; exit 1; }
type git >/dev/null 2>&1 || { echo >&2 "I require git but it's not installed.  Aborting."; exit 1; }
type kubectl >/dev/null 2>&1 || { echo >&2 "I require kubectl but it's not installed.  Aborting."; exit 1; }
type jq >/dev/null 2>&1 || { echo >&2 "I require jq but it's not installed.  Aborting."; exit 1; }
type htpasswd >/dev/null 2>&1 || { echo >&2 "I require htpasswd but it's not installed. Please, install 'apache2-utils'. Aborting."; exit 1; }
type sha256sum >/dev/null 2>&1 || { echo >&2 "I require sha256sum but it's not installed. Aborting."; exit 1; }


SRC_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
mkdir -p "$TMP_DIR"
cd "$TMP_DIR"
#git clone --depth 1 https://github.com/qw1mb0/kubernetes-fcht.git
cp -r ${SRC_DIR} ${TMP_DIR} 
cd "$WORKDIR"

function install {
  PASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
  PASSWORD_BASE64=$(echo -n "$PASSWORD" | base64 -w0)
  BASIC_AUTH_SECRET=$(echo "$PASSWORD" | htpasswd -ni admin | base64 -w0)
  CLICKHOUSE_PASSWORD=$(echo -n $CLICKHOUSE_PASS | sha256sum | tr -d '-' | tr -d ' ')
  CLICKHOUSE_HOST="clickhouse$KUBE_HOST"
  TABIX_HOST="tabix$KUBE_HOST"
  # install basic-auth secret
  sed -i -e "s%##BASIC_AUTH_SECRET##%$BASIC_AUTH_SECRET%" -e "s%##PLAINTEXT_PASSWORD##%$PASSWORD_BASE64%" \
              manifests/ingress/basic-auth-secret.yaml
  # install ingress host
  sed -i -e "s/##CLICKHOUSE_HOST##/$CLICKHOUSE_HOST/g" manifests/ingress/clickhouse.yaml
  sed -i -e "s/##TABIX_HOST##/$TABIX_HOST/g" manifests/ingress/tabix.yaml
  # set storage for clickhouse
  sed -i -e "s/##STORAGE_SIZE##/$STORAGE_SIZE/g" manifests/clickhouse/clickhouse.yaml
  sed -i -e "s/##STORAGE_CLASS_NAME##/$STORAGE_CLASS_NAME/g" manifests/clickhouse/clickhouse.yaml
  sed -i -e "s/##CLICKHOUSE_PASS##/$CLICKHOUSE_PASS/g" manifests/clickhouse/clickhouse.yaml
  sed -i -e "s/##CLICKHOUSE_PASS##/$CLICKHOUSE_PASS/g" manifests/fluentd/fluentd-ds.yaml
  sed -i -e "s/##CLICKHOUSE_DB##/$CLICKHOUSE_DB/g" manifests/clickhouse/clickhouse.yaml
  sed -i -e "s/##CLICKHOUSE_DB##/$CLICKHOUSE_DB/g" manifests/fluentd/fluentd-ds.yaml
  sed -i -e "s/##K8S_LOGS_TABLE##/$K8S_LOGS_TABLE/g" manifests/clickhouse/clickhouse.yaml
  sed -i -e "s/##K8S_LOGS_TABLE##/$K8S_LOGS_TABLE/g" manifests/fluentd/fluentd-ds.yaml
  # set clickhouse password
  sed -i -e "s/##CLICKHOUSE_PASS##/$CLICKHOUSE_PASSWORD/g" manifests/clickhouse/clickhouse-configmap.yaml
  sed -i -e "s/##CLICKHOUSE_PASS##/$CLICKHOUSE_PASSWORD/g" manifests/fluentd/fluentd-ds.yaml
  if [ -n "$STORAGE_NAMESPACE" ] ;
  then
    export STORAGE_NAMESPACE=$STORAGE_NAMESPACE
    export STORAGE_CLASS_NAME=$STORAGE_CLASS_NAME
  fi
  $DEPLOY_SCRIPT
  echo '##################################'
  echo "Login: admin"
  echo "Password: $PASSWORD"
  echo '##################################'
}

function upgrade {
  PASSWORD=$(kubectl -n "$NAMESPACE" get secret basic-auth -o json | jq .data.password -r | base64 -d)
  PASSWORD_BASE64=$(echo -n "$PASSWORD" | base64 -w0)
  CLICKHOUSE_HOST=$(kubectl -n "$NAMESPACE" get ingress clickhouse-ingress -o json | jq -r '.spec.rules[0].host')
  BASIC_AUTH_SECRET=$(echo "$PASSWORD" | htpasswd -ni admin | base64 -w0)
  # install basic-auth secret
  sed -i -e "s%##BASIC_AUTH_SECRET##%$BASIC_AUTH_SECRET%" -e "s%##PLAINTEXT_PASSWORD##%$PASSWORD_BASE64%" \
              manifests/ingress/basic-auth-secret.yaml
  # install ingress host
  sed -i -e "s/##CLICKHOUSE_HOST##/$CLICKHOUSE_HOST/g" manifests/ingress/ingress.yaml
  $DEPLOY_SCRIPT
}

if [ "$MODE" == "install" ]
then
  KUBE_HOST="$1"
  if [ ! "$KUBE_HOST" ] ; then echo "KUBE_HOST arguments required. See '--help' for more information."; exit 1; fi
  kubectl get ns "$NAMESPACE" >/dev/null 2>&1 && FIRST_INSTALL="false"
  if [ "$FIRST_INSTALL" == "true" ]
  then
    install
  else
    echo "Namespace $NAMESPACE exists. Please, delete or run with the --upgrade option it to avoid shooting yourself in the foot."
  fi
elif [ "$MODE" == "upgrade" ]
then
  kubectl get ns "$NAMESPACE" >/dev/null 2>&1 || (echo "Namespace '$NAMESPACE' does not exist. Please, install operator with '-i' option first." ; exit 1)
  upgrade
elif [ "$MODE" == "delete" ]
then
  $TEARDOWN_SCRIPT || true
  kubectl delete ns "$NAMESPACE" || true
fi

function cleanup {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

