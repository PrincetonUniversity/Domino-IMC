#!/bin/bash
# setup-v4l2.sh - Script to set up v4l2loopback after reboot
# Make this executable with: chmod +x setup-v4l2.sh

echo "Setting up v4l2loopback module..."

# Start Xvfb
Xvfb :99 -ac &

# Start PulseAudio if not running and Load the null sink
pulseaudio --start || true
sleep 2
pactl load-module module-null-sink sink_name=dummy

# Configure firewall rules
echo "Configuring firewall rules..."
# Allow UDP for WebRTC and STUN/TURN
sudo iptables -A INPUT -p udp --dport 3478 -j ACCEPT  # STUN server
sudo iptables -A INPUT -p udp --dport 8888 -j ACCEPT  # Your signaling server
sudo iptables -A INPUT -p udp --dport 49152:65535 -j ACCEPT  # WebRTC media
# Allow TCP for signaling and ICE-TCP fallback
sudo iptables -A INPUT -p tcp --dport 8888 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 49152:65535 -j ACCEPT

# Update package list
sudo apt update

# Install kernel headers for current kernel
echo "Installing kernel headers..."
sudo apt install -y linux-headers-$(uname -r)

# Install extra kernel modules with video device support
echo "Installing extra kernel modules..."
sudo apt install -y linux-modules-extra-$(uname -r)

# Load the videodev module (dependency)
echo "Loading videodev module..."
sudo modprobe videodev

# Load the v4l2loopback module
echo "Loading v4l2loopback module..."
sudo modprobe v4l2loopback

# Verify it's working
echo "Verifying installation..."
if lsmod | grep -q v4l2loopback; then
    echo "✅ v4l2loopback loaded successfully!"
else
    echo "❌ Failed to load v4l2loopback. Check dmesg for errors."
fi

echo "Setup complete."

