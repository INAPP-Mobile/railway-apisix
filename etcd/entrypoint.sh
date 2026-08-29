#!/bin/bash
# etcd entrypoint: start etcd DIRECTLY (bypass bitnami wrapper setup.sh which
# runs a validation etcd that starts+closes), wait for readiness, seed APISIX
# bootstrap routes, then keep etcd in foreground.
#
# Config via env vars (bitnami image style). Template sets:
#   ETCD_ADVERTISE_CLIENT_URLS  <- http://${{RAILWAY_PRIVATE_DOMAIN}}:2379
# We must set the rest here because the bitnami run.sh (which normally exports
# them) is bypassed:
#   ETCD_DATA_DIR            <- /bitnami/etcd/data (volume, writable; the
#                               CWD-relative default.etcd is NOT writable →
#                               "cannot access data directory: permission denied")
#   ETCD_LISTEN_CLIENT_URLS  <- http://0.0.0.0:2379 (else image default listens
#                               on localhost only and the private network
#                               cannot reach it)
#
# Do NOT pass --advertise-client-urls as a flag: etcd exits with
# "conflicting environment variable is shadowed" when ETCD_ADVERTISE_CLIENT_URLS
# is also set.

set -e

export ETCD_DATA_DIR="${ETCD_DATA_DIR:-/bitnami/etcd/data}"
export ETCD_LISTEN_CLIENT_URLS="${ETCD_LISTEN_CLIENT_URLS:-http://0.0.0.0:2379}"
export ETCD_INITIAL_CLUSTER_STATE="${ETCD_INITIAL_CLUSTER_STATE:-new}"

echo "[etcd-entry] starting etcd directly (env-driven)"
echo "[etcd-entry] ETCD_ADVERTISE_CLIENT_URLS=${ETCD_ADVERTISE_CLIENT_URLS:-<unset>}"
echo "[etcd-entry] ETCD_LISTEN_CLIENT_URLS=${ETCD_LISTEN_CLIENT_URLS}"
echo "[etcd-entry] ETCD_DATA_DIR=${ETCD_DATA_DIR}"

# Run etcd binary directly in background with no CLI flags — all config derives
# from ETCD_* env vars.
/opt/bitnami/etcd/bin/etcd &
ETCD_PID=$!

# Wait for etcd to be ready (max 120s) using loopback — we are etcd.
export ETCDCTL_ENDPOINTS="http://127.0.0.1:2379"
SEEDED=0
for i in $(seq 1 120); do
  if /opt/bitnami/etcd/bin/etcdctl --endpoints="${ETCDCTL_ENDPOINTS}" endpoint health >/dev/null 2>&1; then
    echo "[etcd-entry] etcd is healthy (after ${i}s)"
    SEEDED=1
    break
  fi
  sleep 1
done

if [ "$SEEDED" = "1" ]; then
  echo "[etcd-entry] seeding APISIX bootstrap routes (idempotent)"
  seed_route() {
    local id="$1" body="$2"
    if ! /opt/bitnami/etcd/bin/etcdctl --endpoints="${ETCDCTL_ENDPOINTS}" get "/apisix/routes/$id" --print-value-only 2>/dev/null | grep -q .; then
      echo "[etcd-entry] creating route $id"
      /opt/bitnami/etcd/bin/etcdctl --endpoints="${ETCDCTL_ENDPOINTS}" put "/apisix/routes/$id" "$body" >/dev/null
    else
      echo "[etcd-entry] route $id exists, skipping"
    fi
  }

  seed_route "health" '{"uri":"/health","plugins":{"response-rewrite":{"status_code":200,"body":"ok"}}}'
  seed_route "admin-proxy" '{"uri":"/apisix/admin/*","upstream":{"type":"roundrobin","nodes":{"127.0.0.1:9180":1}},"plugins":{"proxy-rewrite":{"regex_uri":["^/apisix/admin/(.*)","/apisix/admin/$1"]}}}'
  seed_route "ui-proxy" '{"uri":"/ui/*","upstream":{"type":"roundrobin","nodes":{"127.0.0.1:9180":1}},"plugins":{"proxy-rewrite":{"regex_uri":["^/ui/(.*)","/ui/$1"]}}}'

  echo "[etcd-entry] bootstrap routes seeded"
else
  echo "[etcd-entry] WARNING: etcd not ready after 120s; check etcd logs"
fi

# Keep etcd in foreground
wait $ETCD_PID