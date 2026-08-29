#!/bin/bash
# apisix entrypoint: wait for etcd, substitute refs into config, start APISIX.
#
# All values come from env vars wired via the Railway template editor:
#   ETCD_HOST        <- ${{etcd.RAILWAY_PRIVATE_DOMAIN}}  (etcd sibling service)
#   APISIX_ADMIN_KEY <- ${{secret(32)}}                   (auto-generated)

set -e

ETCD_HOST="${ETCD_HOST:-etcd.railway.internal}"
ETCD_PORT="${ETCD_PORT:-2379}"
ADMIN_KEY="${APISIX_ADMIN_KEY:-}"

echo "[apisix-entry] waiting for etcd at ${ETCD_HOST}:${ETCD_PORT} ..."

probe_ok() {
  local addr
  for addr in $(getent ahostsv4 "${ETCD_HOST}" 2>/dev/null | awk '{print $1}' | sort -u); do
    if (exec 3<>/dev/tcp/${addr}/${ETCD_PORT}) 2>/dev/null; then
      exec 3>&- 3<&-
      return 0
    fi
  done
  if (exec 3<>/dev/tcp/${ETCD_HOST}/${ETCD_PORT}) 2>/dev/null; then
    exec 3>&- 3<&-
    return 0
  fi
  return 1
}

READY=0
for i in $(seq 1 120); do
  if probe_ok; then
    echo "[apisix-entry] etcd is reachable after ${i}s"
    READY=1
    break
  fi
  sleep 1
done

if [ "$READY" != "1" ]; then
  echo "[apisix-entry] ERROR: etcd not reachable after 120s, aborting"
  exit 1
fi

# Substitute template refs into config.yaml (APISIX config has no env interpolation)
sed -i "s|__ETCD_HOST__|${ETCD_HOST}|g" /usr/local/apisix/conf/config.yaml
echo "[apisix-entry] config.yaml etcd host set to ${ETCD_HOST}"

if [ -n "$ADMIN_KEY" ]; then
  sed -i "s|__ADMIN_KEY__|${ADMIN_KEY}|g" /usr/local/apisix/conf/config.yaml
  echo "[apisix-entry] config.yaml admin key set (from env)"
else
  echo "[apisix-entry] WARNING: APISIX_ADMIN_KEY not set — keeping placeholder"
fi

echo "[apisix-entry] starting APISIX..."
exec /docker-entrypoint.sh docker-start