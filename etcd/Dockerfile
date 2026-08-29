FROM bitnamilegacy/etcd:3.5.11
USER root
EXPOSE 2379
ENV ALLOW_NONE_AUTHENTICATION=yes
COPY --chmod=755 entrypoint.sh /usr/local/bin/etcd-seed-entrypoint.sh
ENTRYPOINT ["/usr/local/bin/etcd-seed-entrypoint.sh"]