FROM haproxytech/haproxy-ubuntu

# Update package list and install required packages
RUN apt-get update && apt-get install -y \
    redis-tools \
    socat \
    bash \
    curl \
    supervisor \
    && rm -rf /var/lib/apt/lists/*

# Create directories
RUN mkdir -p /var/lib/config /var/log/supervisor /usr/local/etc/haproxy /scripts

VOLUME /var/lib/config

# Copy configuration files
COPY haproxy.cfg /usr/local/etc/haproxy/haproxy.cfg
COPY sentinel-monitor.sh /scripts/sentinel-monitor.sh
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Make scripts executable
RUN chmod +x /scripts/sentinel-monitor.sh
RUN chown -R 0660 /var/lib/config

# Expose ports
EXPOSE 6379 8404

# Use supervisor to run both HAProxy and the monitoring script
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]