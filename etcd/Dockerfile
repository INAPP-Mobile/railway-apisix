FROM bitnamilegacy/etcd:3.5.11
ENV ALLOW_NONE_AUTHENTICATION=yes
ENV ETCD_ADVERTISE_CLIENT_URLS=http://etcd.railway.internal:2379
COPY --chmod=755 entrypoint.sh /usr/local/bin/etcd-seed-entrypoint.sh
ENTRYPOINT ["/usr/local/bin/etcd-seed-entrypoint.sh"]