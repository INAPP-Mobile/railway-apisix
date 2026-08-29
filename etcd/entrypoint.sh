#!/bin/bash
# etcd entrypoint: render config from template (dynamic advertise URL), chown
# the volume, then let the bitnami wrapper generate the real etcd.yaml, drop to
# UID 1001, and run etcd in foreground. A detached subshell seeds APISIX routes.
#
# ETCD_ADVERTISE_CLIENT_URLS is set via the template editor:
#   value: http://${{RAILWAY_PRIVATE_DOMAIN}}:2379

set -euo pipefail

ETCD_DAEMON_USER="${ETCD_DAEMON_USER:-1001}"
CONF_DIR="${ETCD_CONF_DIR:-/opt/bitnami/etcd/conf}"
CONF_FILE="${ETCD_CONF_FILE:-${CONF_DIR}/etcd.yaml}"
TMPL="/opt/bitnami/etcd/conf/etcd.yaml.tmpl"

# The bitnami wrapper only creates etcd.yaml if ETCD_CFG_* vars exist AND the
# file already exists (etcd_conf_write uses `[[ -f ]]` guard + yq on the file).
# So we pre-create a templated conf with the dynamic advertise URL, letting the
# wrapper's run.sh pick it up via --config-file.
ADVERTISE_URL="${ETCD_ADVERTISE_CLIENT_URLS:-http://127.0.0.1:2379}"
if [ -f "$TMPL" ]; then
  sed "s|__ADVERTISE_URL__|${ADVERTISE_URL}|g" "$TMPL" > "$CONF_FILE"
  echo "[etcd-entry] rendered $CONF_FILE with advertise-url=${ADVERTISE_URL}"
else
  echo "[etcd-entry] WARNING: $TMPL missing; not pre-creating conf"
fi

# Railway bind-mounts the volume root-owned; bitnami drops to UID 1001, so fix
# ownership up front (we run as root via Dockerfile USER root).
echo "[etcd-entry] ensuring /bitnami/etcd/data is owned by UID ${ETCD_DAEMON_USER}"
mkdir -p /bitnami/etcd/data
chown -R "${ETCD_DAEMON_USER}:0" /bitnami/etcd

# --- Seeder (detached; wrapper runs foreground below) -------------------------
(
  export ETCDCTL_ENDPOINTS="http://127.0.0.1:2379"
  SEEDED=0
  for i in $(seq 1 180); do
    if /opt/bitnami/etcd/bin/etcdctl --endpoints="${ETCDCTL_ENDPOINTS}" endpoint health >/dev/null 2>&1; then
      echo "[seed] etcd is healthy (after ${i}s)"
      SEEDED=1
      break
    fi
    sleep 1
  done

  if [ "$SEEDED" = "1" ]; then
    echo "[seed] seeding APISIX bootstrap routes (idempotent)"
    seed_route() {
      local id="$1" body="$2"
      if ! /opt/bitnami/etcd/bin/etcdctl --endpoints="${ETCDCTL_ENDPOINTS}" get "/apisix/routes/$id" --print-value-only 2>/dev/null | grep -q .; then
        echo "[seed] creating route $id"
        /opt/bitnami/etcd/bin/etcdctl --endpoints="${ETCDCTL_ENDPOINTS}" put "/apisix/routes/$id" "$body" >/dev/null
      else
        echo "[seed] route $id exists, skipping"
      fi
    }

    seed_route "health" '{"uri":"/health","plugins":{"response-rewrite":{"status_code":200,"body":"ok"}}}'
    seed_route "admin-proxy" '{"uri":"/apisix/admin/*","upstream":{"type":"roundrobin","nodes":{"127.0.0.1:9180":1}},"plugins":{"proxy-rewrite":{"regex_uri":["^/apisix/admin/(.*)","/apisix/admin/$1"]}}}'
    seed_route "ui-proxy" '{"uri":"/ui/*","upstream":{"type":"roundrobin","nodes":{"127.0.0.1:9180":1}},"plugins":{"proxy-rewrite":{"regex_uri":["^/ui/(.*)","/ui/$1"]}}}'
    echo "[seed] bootstrap routes seeded"
  else
    echo "[seed] WARNING: etcd not ready after 180s; skipping route seeding"
  fi
) &

# The bitnami wrapper (foreground, replaces this shell via exec):
#   - generates the real etcd.yaml (writes initial-cluster via yq)
#   - drops from root to UID 1001 and execs etcd --config-file
exec /opt/bitnami/scripts/etcd/entrypoint.sh /opt/bitnami/scripts/etcd/run.sh