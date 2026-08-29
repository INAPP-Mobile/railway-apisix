FROM bitnamilegacy/etcd:3.5.11
USER root
EXPOSE 2379
ENV ALLOW_NONE_AUTHENTICATION=yes
ENV ETCD_CONF_DIR=/opt/bitnami/etcd/conf
COPY --chmod=644 etcd.yaml.tmpl /opt/bitnami/etcd/conf/etcd.yaml.tmpl
COPY --chmod=755 entrypoint.sh /usr/local/bin/etcd-seed-entrypoint.sh
ENTRYPOINT ["/usr/local/bin/etcd-seed-entrypoint.sh"]