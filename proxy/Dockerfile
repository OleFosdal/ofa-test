FROM haproxytech/haproxy-ubuntu:3.3
RUN apt-get update
COPY haproxy.cfg /var/lib/config/haproxy.cfg
CMD ["haproxy", "-f", "/var/lib/config/haproxy.cfg"]