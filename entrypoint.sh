#!/bin/bash
# apisix entrypoint: wait for etcd, substitute host into config, start APISIX.

set -e

ETCD_HOST="${ETCD_HOST:-etcd.railway.internal}"
ETCD_PORT="${ETCD_PORT:-2379}"

echo "[apisix-entry] waiting for etcd at ${ETCD_HOST}:${ETCD_PORT} ..."

READY=0
for i in $(seq 1 120); do
  if (exec 3<>/dev/tcp/${ETCD_HOST}/${ETCD_PORT}) 2>/dev/null; then
    exec 3>&- 3<&-
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

# Substitute the etcd host into config.yaml (APISIX config has no env interpolation)
sed -i "s|__ETCD_HOST__|${ETCD_HOST}|g" /usr/local/apisix/conf/config.yaml
echo "[apisix-entry] config.yaml etcd host set to ${ETCD_HOST}"

echo "[apisix-entry] starting APISIX..."
exec /docker-entrypoint.sh docker-start