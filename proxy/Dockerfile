FROM haproxytech/haproxy-ubuntu
RUN mkdir -p /var/lib/config
RUN apt-get update
VOLUME /var/lib/config
RUN chown -R 0660 /var/lib/config
COPY haproxy.cfg /var/lib/config/haproxy.cfg
CMD ["haproxy", "-f", "/var/lib/config/haproxy.cfg"]