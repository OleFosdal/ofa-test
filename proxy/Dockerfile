FROM haproxy

# Install required packages
RUN apk add --no-cache \
    redis \
    socat \
    bash \
    curl \
    supervisor

RUN apt-get update

# Create directories
RUN mkdir -p /var/lib/config
RUN mkdir -p /var/log/supervisor /usr/local/etc/haproxy /scripts

VOLUME /var/lib/config
RUN chown -R 0660 /var/lib/config

# Copy configuration files
COPY haproxy.cfg /usr/local/etc/haproxy/haproxy.cfg
COPY sentinel-monitor.sh /scripts/sentinel-monitor.sh
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Make scripts executable
RUN chmod +x /scripts/sentinel-monitor.sh

# Expose ports
EXPOSE 6379 8404

# Use supervisor to run both HAProxy and the monitoring script
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]