
# Hosts

**SFU:**
```
Host paws4gcore
    HostName 128.112.92.75
    User paws_admin
    ProxyJump om1100@cycles
```

# Experiment Setup

**Install Mediasoup:**

```
make install-mediasoup-demo
```

**Build container:**

```
sudo docker build --tag mediasoup .
```

**Run Mediasoup:**

```
sudo docker run --rm --name ms -e INTERACTIVE=false \
    -p 0.0.0.0:3000:3000/tcp -p 0.0.0.0:4443:4443/tcp -p 0.0.0.0:40000-40099:40000-40099/udp \
    -it mediasoup:latest /bin/bash -c 'pm2 start --no-daemon /mediasoup/ecosystem.config.js' \
    -e MEDIA_SOUP_LISTEN_IP=0.0.0.0 -e MEDIASOUP_ANNOUNCED_IP=192.168.68.2
```

**Install client:**

```
make install-client
```

# Experiment teardown:

**Stop Mediasoup:**

```
sudo docker stop ms
```

# Docker commands

**List Docker images:**

```
sudo docker image ls
```

**List Docker containers:**

```
sudo docker container ls --all
```

**Remove Docker image:**

```
sudo docker image rm mediasoup
```

**Remove certificate from certificate database on client:**

```
certutil -D -d sql:$HOME/.pki/nssdb -n mediasoup
```
