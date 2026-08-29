#!/bin/bash
# etcd entrypoint: start etcd, wait for readiness, seed APISIX bootstrap routes.

set -e

# Start etcd in background
/opt/bitnami/scripts/etcd/entrypoint.sh /opt/bitnami/scripts/etcd/run.sh &
ETCD_PID=$!

# Wait for etcd to be ready (max 60s)
for i in $(seq 1 60); do
  if etcdctl endpoint health >/dev/null 2>&1; then
    echo "[seed] etcd is ready"
    break
  fi
  sleep 1
done

# Seed APISIX bootstrap routes (idempotent — only if not present)
seed_route() {
  local id="$1" body="$2"
  if ! etcdctl get "/apisix/routes/$id" --print-value-only 2>/dev/null | grep -q .; then
    echo "[seed] creating route $id"
    etcdctl put "/apisix/routes/$id" "$body" >/dev/null
  else
    echo "[seed] route $id already exists, skipping"
  fi
}

seed_route "health" '{"uri":"/health","plugins":{"response-rewrite":{"status_code":200,"body":"ok"}}}'
seed_route "admin-proxy" '{"uri":"/apisix/admin/*","upstream":{"type":"roundrobin","nodes":{"127.0.0.1:9180":1}},"plugins":{"proxy-rewrite":{"regex_uri":["^/apisix/admin/(.*)","/apisix/admin/$1"]}}}'
seed_route "ui-proxy" '{"uri":"/ui/*","upstream":{"type":"roundrobin","nodes":{"127.0.0.1:9180":1}},"plugins":{"proxy-rewrite":{"regex_uri":["^/ui/(.*)","/ui/$1"]}}}'

echo "[seed] bootstrap routes seeded"

# Keep etcd in foreground
wait $ETCD_PID