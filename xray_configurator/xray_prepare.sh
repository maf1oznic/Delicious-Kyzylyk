#!/bin/bash

if [ ! -f /connection/connection.txt ]; then

unzip xray.zip

# Select transport configuration
if [ "$TRANSPORT" = "grpc" ]; then
    CONFIG_FILE="config_grpc.json"
    CONNSTRING_FILE="connstring_grpc.txt"
    CLIENT_FILE="client_grpc.json"
    echo "Using gRPC transport"

elif [ "$TRANSPORT" = "xhttp" ]; then
    CONFIG_FILE="config_xhttp.json"
    CONNSTRING_FILE="connstring_xhttp.txt"
    CLIENT_FILE="client_xhttp.json"
    echo "Using XHTTP transport"

else
    CONFIG_FILE="config_tcp.json"
    CONNSTRING_FILE="connstring_tcp.txt"
    CLIENT_FILE="client_tcp.json"
    echo "Using TCP transport"
fi

# XRay config
rm /etc/xray/config.json
cp $CONFIG_FILE /etc/xray/config.json

key_x25519=$(/xray x25519)
PKEY=$(echo "$key_x25519" | awk '/Private key:/ {print $3}')
PUBKEY=$(echo "$key_x25519" | awk '/Public key:/ {print $3}')

SID=$(openssl rand -hex 8)

# Determine dest and xver based on SELFSNI
if [ "$SELFSNI" = "true" ]; then
    DEST="nginx:8443"
    XVER=1
    echo "Using self-signed SNI (dest: $DEST, xver: $XVER)"
else
    DEST="#SNI:443"
    XVER=0
    echo "Using public SNI (dest: $DEST, xver: $XVER)"
fi

# Replace placeholders in config
sed -i -e "s/#PKEY/$PKEY/g" /etc/xray/config.json
sed -i -e "s/#SID/$SID/g" /etc/xray/config.json
sed -i -e "s|#DEST|$DEST|g" /etc/xray/config.json
sed -i -e "s/#SNI/$SNI/g" /etc/xray/config.json
sed -i -e "s/#XVER/$XVER/g" /etc/xray/config.json

# Inject jump outbound or restore `direct` outbound depending on `JUMP`.
# Insert placeholder-based jump block and then replace placeholders using sed
awk -v jump="$JUMP" '{
    if ($0 ~ /#JUMP_OUTBOUND/) {
        if (jump == "true") {
            print "        {";
            print "            \"tag\": \"jump\",";
            print "            \"protocol\": \"vless\",";
            print "            \"settings\": {";
            print "                \"vnext\": [";
            print "                    {";
            print "                        \"port\": #EXIT_PORT,";
            print "                        \"users\": [";
            print "                            {";
            print "                                \"id\": \"#EXIT_UUID\",";
            print "                                \"flow\": \"xtls-rprx-vision\",";
            print "                                \"encryption\": \"none\"";
            print "                            }";
            print "                        ],";
            print "                        \"address\": \"#EXIT_IP\"";
            print "                    }";
            print "                ]";
            print "            },";
            print "            \"streamSettings\": {";
            print "                \"network\": \"tcp\",";
            print "                \"security\": \"reality\",";
            print "                \"realitySettings\": {";
            print "                    \"shortId\": \"#EXIT_SHORT_ID\",";
            print "                    \"publicKey\": \"#EXIT_PUBLIC_KEY\",";
            print "                    \"serverName\": \"#EXIT_SNI_DEST\",";
            print "                    \"fingerprint\": \"chrome\"";
            print "                }";
            print "            }";
            print "        },";
        } else {
            print "        {";
            print "            \"protocol\": \"freedom\",";
            print "            \"tag\": \"direct\"";
            print "        },";
        }
    } else {
        print;
    }
}' /etc/xray/config.json > /etc/xray/config.json.tmp && mv /etc/xray/config.json.tmp /etc/xray/config.json

# Now replace jump placeholders from environment (no defaults; if empty they'll be blank)
sed -i -e "s/#EXIT_PORT/$EXIT_PORT/g" /etc/xray/config.json
sed -i -e "s/#EXIT_UUID/$EXIT_UUID/g" /etc/xray/config.json
sed -i -e "s/#EXIT_IP/$EXIT_IP/g" /etc/xray/config.json
sed -i -e "s/#EXIT_SHORT_ID/$EXIT_SHORT_ID/g" /etc/xray/config.json
sed -i -e "s/#EXIT_PUBLIC_KEY/$EXIT_PUBLIC_KEY/g" /etc/xray/config.json
sed -i -e "s/#EXIT_SNI_DEST/$EXIT_SNI_DEST/g" /etc/xray/config.json

# Connection string for ease of access
IP=$(curl -s ipinfo.io/ip)

BASECONNSTRING=$(cat $CONNSTRING_FILE)
BASECONNSTRING=$(echo "$BASECONNSTRING" |
sed "s/#IP/$IP/g" |
sed "s/#SNI/$SNI/g" |
sed "s/#PUBKEY/$PUBKEY/g" |
sed "s/#SID/$SID/g")

# Generate users
CLIENTSARRAY=''
CONNSTRINGARRAY=''
for i in $(seq 1 $USERCOUNT);
do
    # New entry in config.json
    NEWCLIENT=$(cat $CLIENT_FILE)
    UUID=$(/xray uuid)
    NEWCLIENT=$(echo "$NEWCLIENT" | sed "s/#UUID/$UUID/g" | sed "s/#USERNAME/"$NAME"_"$i"/g")    
    if [ ! $i = $USERCOUNT ]; then
    NEWCLIENT+=$',@'
    fi
    CLIENTSARRAY+=$NEWCLIENT

    # New entry in connstring.txt
    NEWCONNSTRING="user_$i:"$'\n'
    NEWCONNSTRING+=$BASECONNSTRING
    NEWCONNSTRING=$(echo "$NEWCONNSTRING" | sed "s/#UUID/$UUID/g") 
    NEWCONNSTRING=$(echo "$NEWCONNSTRING" | sed "s/#NAME/"$NAME"_"$i"/g")
    
    CONNSTRINGARRAY+=$NEWCONNSTRING$'\n'
done

touch /connection/connstring.txt
echo "$CONNSTRINGARRAY" > /connection/connstring.txt

sed -i -e "s|#CLIENTS|$CLIENTSARRAY|g" /etc/xray/config.json
sed -i -e "s|@|\\n|g" /etc/xray/config.json

# Connection file to serve on nginx
touch /connection/connection.txt

echo '{' >> /connection/connection.txt
echo "\"PUBKEY\" : \"$PUBKEY\"," >> /connection/connection.txt
echo "\"UUID\" : \"$UUID\"," >> /connection/connection.txt
echo "\"SID\" : \"$SID\"," >> /connection/connection.txt
echo "\"SNI\" : \"$SNI\"," >> /connection/connection.txt
echo "\"TRANSPORT\" : \"$TRANSPORT\"," >> /connection/connection.txt
echo "\"SELFSNI\" : \"$SELFSNI\"" >> /connection/connection.txt
echo '}' >> /connection/connection.txt

fi

echo "Configuration is complete for $TRANSPORT transport"