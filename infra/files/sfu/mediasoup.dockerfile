FROM node:18-bookworm

RUN apt update && \
    apt-get install -y git build-essential python3-pip && \
    npm install -g npm@10.2.1 && \
    npm install -g pm2 && \
    git clone https://github.com/versatica/mediasoup-demo.git /mediasoup && \
    cd /mediasoup && git checkout v3 && \
    cd /mediasoup/server && npm install && \
    cd /mediasoup/app && npm install --legacy-peer-deps && \
    mkdir -p /mediasoup/server/certs

ADD config.js /mediasoup/server/config.js
ADD privkey.pem /mediasoup/server/certs/privkey.pem
ADD fullchain.pem /mediasoup/server/certs/fullchain.pem
ADD ecosystem.config.js /mediasoup/ecosystem.config.js
