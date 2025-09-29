
FROM node:18-bookworm

ADD fullchain.pem mediasoup-client.js package.json /root/

WORKDIR /root

RUN wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb && \
    # install dependencies for chrome:
    apt-get update && \
    apt-get install -y fonts-liberation libasound2 libatk-bridge2.0-0 libatk1.0-0 libatspi2.0-0 \
        libnspr4 libnss3 libnss3-tools libcups2 libu2f-udev libvulkan1 xdg-utils libdbus-1-3 \
        libdrm2 libgbm1 libgtk-3-0 && \
    # install chrome:
    dpkg -i google-chrome-stable_current_amd64.deb && \
    rm google-chrome-stable_current_amd64.deb && \
    # install certificate:
    certutil -d sql:/root/.pki/nssdb -A -t "P,," -n mediasoup -i fullchain.pem && \
    # install mediasoup-client.js
    npm install -g npm@10.2.1 && \
    npm install && \
    chmod u+x /root/mediasoup-client.js

ENTRYPOINT /root/mediasoup-client.js
