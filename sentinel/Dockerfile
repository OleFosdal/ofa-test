FROM eqalpha/keydb:x86_64_v6.3.4
RUN mkdir -p /var/lib/config
RUN apt-get update
VOLUME /var/lib/config
RUN chown -R 0660 /var/lib/config
COPY ./keydb.conf /var/lib/config 
CMD keydb-server /var/lib/config/keydb.conf