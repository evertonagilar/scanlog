FROM python:3.12-alpine

RUN adduser -u 1000 -D -H scanuser && \
    apk add --no-cache rsync openssh bash jq && \
    pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir streamlit

WORKDIR /opt/scan
COPY dashboard_streamlit.py /usr/local/bin/dashboard_streamlit.py
COPY scanlog.sh /usr/local/bin/scanlog.sh
RUN chown -R scanuser:scanuser /opt/scan
USER scanuser

ENTRYPOINT ["/usr/local/bin/scanlog.sh"]
