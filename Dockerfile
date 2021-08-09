FROM mariadb/maxscale:2.5.14
LABEL org.opencontainers.image.authors="wdmaster@gmail.com"

# Setup for Galera Service (GS), not for Master-Slave environments

# We set some defaults for config creation. Can be overwritten at runtime.
ENV MAX_USER="maxscale" \
    MAX_PASS="maxscalepass" \
    ENABLE_ROOT_USER=0 \
    SPLITTER_PORT=3306 \
    ROUTER_PORT=3307 \
    API_PORT=8989 \
    CONNECTION_TIMEOUT=600 \
    PERSIST_POOLMAX=0 \
    PERSIST_MAXTIME=3600s \
    BACKEND_SERVER_LIST="server1 server2 server3" \
    BACKEND_SERVER_PORT="3306" \
    USE_SQL_VARIABLES_IN="all"

# Move configuration file in directory for exports
RUN mkdir -p /etc/maxscale.d \
    && cp /etc/maxscale.cnf.template /etc/maxscale.d/maxscale.cnf \
    && ln -sf /etc/maxscale.d/maxscale.cnf /etc/maxscale.cnf \
    && chown root:maxscale /etc/maxscale.d/maxscale.cnf \
    && chmod g+w /etc/maxscale.d/maxscale.cnf

# VOLUME for custom configuration
VOLUME ["/etc/maxscale.d"]

# We expose our set Listener Ports
EXPOSE $SPLITTER_PORT $ROUTER_PORT $API_PORT

COPY docker-entrypoint.sh /docker-entrypoint-mxs.sh
RUN chmod 755 /docker-entrypoint-mxs.sh

ENTRYPOINT ["/docker-entrypoint-mxs.sh"]

CMD ["maxscale", "-d", "-U", "maxscale", "-l", "stdout"]

