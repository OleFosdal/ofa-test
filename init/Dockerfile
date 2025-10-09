FROM redis:latest

# Copy the initialization script
COPY init-cluster.sh /usr/local/bin/init-cluster.sh

# Make it executable
RUN chmod +x /usr/local/bin/init-cluster.sh

# Run the initialization script
CMD ["/usr/local/bin/init-cluster.sh"]
