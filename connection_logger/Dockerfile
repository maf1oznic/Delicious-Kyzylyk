FROM python:3.11-alpine

RUN apk add --no-cache docker-cli

WORKDIR /app
COPY xray_connection_logger.py .

VOLUME ["/logs"]

CMD ["python3", "/app/xray_connection_logger.py"]