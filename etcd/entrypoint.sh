#!/bin/bash
# etcd entrypoint: chown the volume (we run as root; bitnami runs as UID 1001),
# then let the bitnami wrapper handle setup + run as the daemon user in
# foreground, while a detached background subshell seeds APISIX bootstrap routes
# once etcd is ready.
#
# ETCD_ADVERTISE_CLIENT_URLS is set via the template editor:
#   value: http://${{RAILWAY_PRIVATE_DOMAIN}}:2379

set -e

ETCD_DAEMON_USER="${ETCD_DAEMON_USER:-1001}"

# Railway bind-mounts the volume root-owned; bitnami runs as UID 1001
# (non-root), so it cannot write /bitnami/etcd/data. Fix ownership up front.
echo "[etcd-entry] ensuring /bitnami/etcd is owned by UID ${ETCD_DAEMON_USER}"
mkdir -p /bitnami/etcd/data
chown -R "${ETCD_DAEMON_USER}:0" /bitnami/etcd
chmod -R g+w /bitnami/etcd

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

# The bitnami wrapper (foreground, replaces this shell via exec) handles:
#   - single-node defaults, extra env → conf file
#   - dropping from root to the daemon user for the etcd process
#   - keeping etcd in foreground
exec /opt/bitnami/scripts/etcd/entrypoint.sh /opt/bitnami/scripts/etcd/run.sh