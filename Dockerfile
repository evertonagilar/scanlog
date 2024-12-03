FROM alpine:latest
RUN apk add --no-cache rsync openssh bash
ADD ufsm-scanlog.sh /opt/ufsm-scanlog.sh
WORKDIR /opt
