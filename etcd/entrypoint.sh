#!/bin/bash
# etcd entrypoint: start etcd DIRECTLY (bypass bitnami wrappers; their setup.sh
# runs a validation etcd that starts+closes, which breaks background/wait flows),
# wait for readiness, seed APISIX bootstrap routes, then keep etcd in foreground.
#
# ETCD_ADVERTISE_CLIENT_URLS is set via the template editor:
#   value: http://${{RAILWAY_PRIVATE_DOMAIN}}:2379

set -e

DATA_DIR="${ETCD_DATA_DIR:-/bitnami/etcd/data}"

echo "[etcd-entry] starting etcd directly: data-dir=${DATA_DIR} advertise=${ETCD_ADVERTISE_CLIENT_URLS:-http://127.0.0.1:2379}"

# Run etcd binary directly in background — no bitnami wrapper that closes the
# server during its setup phase.
/opt/bitnami/etcd/bin/etcd \
  --name=default \
  --data-dir="$DATA_DIR" \
  --listen-client-urls=http://0.0.0.0:2379 \
  --advertise-client-urls="${ETCD_ADVERTISE_CLIENT_URLS:-http://127.0.0.1:2379}" \
  --listen-peer-urls=http://localhost:2380 \
  --initial-advertise-peer-urls=http://localhost:2380 \
  --initial-cluster=default=http://localhost:2380 \
  --log-level=info \
  &
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