#!/bin/bash
# etcd entrypoint: render config from template (dynamic advertise URL), ensure
# the volume exists, then run etcd DIRECTLY as root with --config-file.
#
# Why not the bitnami wrapper: it drops to a daemon user ("etcd", dynamically
# created, unpredictable UID) that can't match the volume chown; it also
# regenerates conf from ETCD_CFG_* vars. Direct root run is deterministic.
#
# ETCD_ADVERTISE_CLIENT_URLS is set via the template editor:
#   value: http://${{RAILWAY_PRIVATE_DOMAIN}}:2379

set -euo pipefail

CONF_DIR="${ETCD_CONF_DIR:-/opt/bitnami/etcd/conf}"
CONF_FILE="${ETCD_CONF_FILE:-${CONF_DIR}/etcd.yaml}"
TMPL="${CONF_DIR}/etcd.yaml.tmpl"

ADVERTISE_URL="${ETCD_ADVERTISE_CLIENT_URLS:-http://127.0.0.1:2379}"
if [ -f "$TMPL" ]; then
  sed "s|__ADVERTISE_URL__|${ADVERTISE_URL}|g" "$TMPL" > "$CONF_FILE"
  echo "[etcd-entry] rendered $CONF_FILE with advertise-url=${ADVERTISE_URL}"
else
  echo "[etcd-entry] WARNING: $TMPL missing; keeping existing conf"
fi

# Railway volume may be fresh/empty; ensure the data dir exists (we run as root).
mkdir -p /bitnami/etcd/data
chmod 700 /bitnami/etcd/data

# --- Seeder (detached) ---
(
  export ETCDCTL_ENDPOINTS="http://127.0.0.1:2379"
  SEEDED=0
  SEED_ERR=/tmp/seed-err.log
  for i in $(seq 1 180); do
    if /opt/bitnami/etcd/bin/etcdctl --endpoints="${ETCDCTL_ENDPOINTS}" endpoint health >/dev/null 2>"$SEED_ERR"; then
      echo "[seed] etcd is healthy (after ${i}s)"
      SEEDED=1
      break
    fi
    if [ $((i % 20)) -eq 0 ]; then
      echo "[seed] attempt ${i} still failing; last err: $(head -c 300 "$SEED_ERR" 2>/dev/null | tr '\n' ' ')"
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

# Run etcd directly (foreground). Removes container-user drop issues entirely.
echo "[etcd-entry] starting etcd (root) with --config-file ${CONF_FILE}"
exec /opt/bitnami/etcd/bin/etcd --config-file "$CONF_FILE"