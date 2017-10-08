# First enter habitat studio by running "hab studio enter"
# Then run this script: "bash /src/configure.sh"

# Install the janus-gateway package
hab pkg install mozillareality/janus-gateway

# Save the path to the janus-gateway package
JANUS_GATEWAY_PATH=$(hab pkg path mozillareality/janus-gateway)

cd $JANUS_GATEWAY_PATH

# Copy the retproxy plugin binary into the janus plugins folder
cp /src/libjanus_retproxy.so ./lib/janus/plugins/libjanus_retproxy.so
chmod 755 ./lib/janus/plugins/libjanus_retproxy.so

# Start the janus-gateway service
hab sup start mozillareality/janus-gateway

# Upload the dtls cert
hab file upload janus-gateway.default 1 /src/dtls.key
hab file upload janus-gateway.default 1 /src/dtls.pem

# Modify janus.cfg to enable the http and websocket API
cat /src/config.toml | hab config apply janus-gateway.default 1
