#!/bin/bash
# etcd entrypoint: start etcd, wait for readiness, seed APISIX bootstrap routes.

set -e

export ETCDCTL_ENDPOINTS="${ETCD_ADVERTISE_CLIENT_URLS:-http://127.0.0.1:2379}"

# Start etcd in background
/opt/bitnami/scripts/etcd/entrypoint.sh /opt/bitnami/scripts/etcd/run.sh &
ETCD_PID=$!

# Wait for etcd to be ready (max 90s)
SEEDED=0
for i in $(seq 1 90); do
  if etcdctl endpoint health >/dev/null 2>&1; then
    echo "[seed] etcd is ready (after ${i}s)"
    SEEDED=1
    break
  fi
  sleep 1
done

if [ "$SEEDED" = "1" ]; then
  # Seed APISIX bootstrap routes (idempotent — only if not present)
  seed_route() {
    local id="$1" body="$2"
    if ! etcdctl get "/apisix/routes/$id" --print-value-only 2>/dev/null | grep -q .; then
      echo "[seed] creating route $id"
      etcdctl put "/apisix/routes/$id" "$body" >/dev/null && echo "[seed] route $id created"
    else
      echo "[seed] route $id already exists, skipping"
    fi
  }

  seed_route "health" '{"uri":"/health","plugins":{"response-rewrite":{"status_code":200,"body":"ok"}}}'
  seed_route "admin-proxy" '{"uri":"/apisix/admin/*","upstream":{"type":"roundrobin","nodes":{"127.0.0.1:9180":1}},"plugins":{"proxy-rewrite":{"regex_uri":["^/apisix/admin/(.*)","/apisix/admin/$1"]}}}'
  seed_route "ui-proxy" '{"uri":"/ui/*","upstream":{"type":"roundrobin","nodes":{"127.0.0.1:9180":1}},"plugins":{"proxy-rewrite":{"regex_uri":["^/ui/(.*)","/ui/$1"]}}}'

  echo "[seed] bootstrap routes seeded"
else
  echo "[seed] WARNING: etcd did not become ready in 90s, skipping route seeding"
fi

# Keep etcd in foreground
wait $ETCD_PID