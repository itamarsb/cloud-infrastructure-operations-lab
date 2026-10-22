FROM zabbix/zabbix-agent2:ubuntu-7.0.30

USER root

# Impede a inicializacao de servicos durante a instalacao.
RUN printf '#!/bin/sh\nexit 101\n' > /usr/sbin/policy-rc.d \
    && chmod 0755 /usr/sbin/policy-rc.d \
    && apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        --no-install-recommends \
        nginx \
        supervisor \
        curl \
    && rm -rf /var/lib/apt/lists/*

# Copia as configuracoes exclusivas do laboratorio.
COPY zabbix_agent2.conf /etc/zabbix/zabbix_agent2.conf
COPY nginx.conf /etc/nginx/nginx.conf
COPY supervisord.conf /etc/supervisor/supervisord.conf

# Confere os executaveis e a configuracao do Nginx.
RUN test -x /usr/sbin/zabbix_agent2 \
    && test -x /usr/sbin/nginx \
    && test -x /usr/bin/supervisord \
    && test -x /usr/bin/supervisorctl \
    && id zabbix \
    && chmod 0644 \
        /etc/zabbix/zabbix_agent2.conf \
        /etc/nginx/nginx.conf \
        /etc/supervisor/supervisord.conf \
    && /usr/sbin/nginx -t -c /etc/nginx/nginx.conf

EXPOSE 10050 8080

STOPSIGNAL SIGTERM

HEALTHCHECK NONE

ENTRYPOINT ["/usr/bin/supervisord"]
CMD ["-c", "/etc/supervisor/supervisord.conf"]
