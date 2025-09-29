#!/bin/bash

# IP and port of Ubuntu 2
TARGET_IP="192.168.68.4"
PORT=12345

# Infinite loop to send data every second
while true
do
    echo -n "0123456789" | nc -u -w 1 "192.168.68.4" 12345
    # echo -n "0123456789" | nc -w 1 "192.168.68.4" 12345
    sleep 3
done
