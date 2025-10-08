FROM haproxy:2.8-alpine
RUN mkdir -p /var/lib/config
RUN mkdir -p /var/log/supervisor /usr/local/etc/haproxy /scripts
RUN apt-get update
VOLUME /var/lib/config
RUN chown -R 0660 /var/lib/config
RUN chown -R 0660 /var/log/supervisor
RUN chown -R 0660 /usr/local/etc/haproxy
RUN chmod +x /scripts/sentinel-monitor.sh
COPY haproxy.cfg /usr/local/etc/haproxy/haproxy.cfg
COPY sentinel-monitor.sh /scripts/sentinel-monitor.sh
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
CMD haproxy -f /usr/local/etc/haproxy/haproxy.cfg & \
    /scripts/sentinel-monitor.sh & \
    wait