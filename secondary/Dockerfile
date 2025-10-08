FROM redis:latest 
RUN mkdir -p /var/lib/config
RUN apt-get update
VOLUME /var/lib/config
RUN chown -R 0660 /var/lib/config
COPY ./redis.conf /var/lib/config 
CMD redis-server /var/lib/config/redis.conf 