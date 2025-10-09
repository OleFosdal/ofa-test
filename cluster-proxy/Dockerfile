FROM ubuntu:22.04

# Install dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    libhiredis-dev \
    && rm -rf /var/lib/apt/lists/*

# Clone and build redis-cluster-proxy
WORKDIR /tmp
RUN git clone https://github.com/RedisLabs/redis-cluster-proxy.git && \
    cd redis-cluster-proxy && \
    make CFLAGS="-fcommon" && \
    make install

# Create config directory
RUN mkdir -p /var/lib/config
VOLUME /var/lib/config

# Copy proxy configuration
COPY proxy.conf /var/lib/config/proxy.conf

# Expose proxy port (redis config handles both )
EXPOSE 7777

# Start the proxy
CMD ["redis-cluster-proxy", "-c", "/var/lib/config/proxy.conf"]
