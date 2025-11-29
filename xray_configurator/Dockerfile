FROM alpine:latest

RUN apk add bash curl openssl unzip bind-tools

COPY xray_prepare.sh /xray_prepare.sh

RUN chmod +x /xray_prepare.sh

COPY Xray-linux-64.zip /xray.zip
RUN mkdir -p /etc/xray

# Copy all config templates
COPY config_tcp.json /config_tcp.json
COPY config_grpc.json /config_grpc.json
COPY config_xhttp.json /config_xhttp.json
COPY connstring_tcp.txt /connstring_tcp.txt
COPY connstring_grpc.txt /connstring_grpc.txt
COPY connstring_xhttp.txt /connstring_xhttp.txt
COPY client_tcp.json /client_tcp.json
COPY client_grpc.json /client_grpc.json
COPY client_xhttp.json /client_xhttp.json

RUN mkdir -p /connection

CMD ["/xray_prepare.sh"]