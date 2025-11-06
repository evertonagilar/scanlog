FROM alpine:3.19
RUN adduser -u 1000 -D -H scanuser && \
    apk add --no-cache rsync openssh bash jq python3
COPY scanlog.sh /usr/local/bin/scanlog.sh
USER scanuser
WORKDIR /opt/scan
ENTRYPOINT ["/usr/local/bin/scanlog.sh"]
