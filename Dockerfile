FROM apache/apisix:3.18.0-debian
COPY config.yaml /usr/local/apisix/conf/config.yaml
COPY --chmod=755 entrypoint.sh /usr/local/bin/apisix-entrypoint.sh
ENTRYPOINT ["/usr/local/bin/apisix-entrypoint.sh"]