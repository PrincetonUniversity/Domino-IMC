# WebRTC Cellular Measurement Testbed

This repository provides the experimental setup and automation scripts used for measuring WebRTC performance over 5G networks.  
It reproduces the setup used in our paper, where:
- One WebRTC client runs on a **Google Cloud VM**, and  
- The other client runs on a **local machine connected via T-Mobile 5G**.

The setup includes video streaming via virtual cameras, synchronized system clocks, and data collection through `tcpdump` and custom packet parsers.

---

## 🧩 Prerequisites

### 1. STUN Server
Use a public STUN server for NAT traversal:
```bash
stun_server_ip: stun.l.google.com
stun_server_port: 19302
```

### 2. NTP Time Synchronization
Install and configure `chrony` for NTP sync:
```bash
sudo apt-get install chrony
sudo vim /etc/chrony/chrony.conf
```
Add the following lines:
```
server ntp1.cs.princeton.edu iburst prefer
server ntp2.cs.princeton.edu iburst prefer
```
Then restart and verify:
```bash
sudo systemctl restart chrony
chronyc tracking
```

### 3. PulseAudio (Audio Handling)
```bash
sudo apt-get update
sudo apt-get install -y pulseaudio
pulseaudio --start
pactl load-module module-null-sink sink_name=dummy
```

### 4. Xvfb (Headless Display for WebRTC on GCP)
```bash
sudo apt-get install -y xvfb
Xvfb :99 -ac &
export DISPLAY=:99
```
To persist this after reboot:
```bash
echo 'export DISPLAY=:99' >> ~/.bashrc
source ~/.bashrc
```

---

## 🎥 Virtual Camera Setup

### Option 1: FFmpeg Virtual Camera
Install dependencies:
```bash
sudo apt install -y ffmpeg v4l2loopback-dkms
sudo modprobe v4l2loopback card_label="Virtual Camera 1" exclusive_caps=1
```

List devices:
```bash
ls -1 /dev/video*
v4l2-ctl -d /dev/video2 --all
```

Stream video via virtual camera:
```bash
ffmpeg -stream_loop -1 -re -i ./raw_video/Zoom1_1080p_barcode_5min.mp4   -vf scale=1920:1080 -pix_fmt yuyv422 -vcodec rawvideo -threads 2   -f v4l2 /dev/video0
```

To also log frame timestamps:
```bash
ffmpeg -stream_loop -1 -re -i ./raw_video/Zoom1_1080p_barcode_5min.mp4   -vf "scale=1920:1080,showinfo" -pix_fmt yuyv422 -vcodec rawvideo -threads 2   -f v4l2 /dev/video0 2> frame_log.txt
```

Play the virtual feed:
```bash
ffplay /dev/video0
```

Reload modules if needed:
```bash
sudo modprobe -r v4l2loopback
sudo modprobe v4l2loopback
```

### Option 2: OBS Virtual Camera
You may alternatively use OBS Studio to emulate a webcam.  
Setup guide: [GeeksForGeeks Tutorial](https://www.geeksforgeeks.org/how-to-create-fake-webcam-streams-on-linux/)

---

## ⚙️ System Monitoring

### CPU Utilization
Record CPU usage during experiment:
```bash
mpstat -P ALL -o JSON 1 10 > cpu.json
```

### 5G USB Modem (Dongle)
- [TriCascade VOS-5G Product Page](https://www.tricascadeinc.com/vos-5g)  
- [User Manual (PDF)](https://www.tricascadeinc.com/_files/ugd/3c10e2_c58e205759d840249ad07d356cf33c9e.pdf)

---

## 🚀 Running the WebRTC Experiment

### GCP Instance (Client 1 / Caller)
1. **SSH into VM**
   ```bash
   ssh fanyi@34.21.77.56
   ```

2. **Start Virtual Camera (optional)**
   ```bash
   cd ~/proj_webrtc/Domino-IMC/zoom_testbed
   sudo modprobe v4l2loopback
   ffmpeg -stream_loop -1 -re -i ./raw_video/Zoom1_1080p_barcode_5min.mp4      -vf scale=1920:1080 -pix_fmt yuyv422 -vcodec rawvideo -threads 2      -f v4l2 /dev/video0
   ```

3. **Run WebRTC Server**
   ```bash
   cd ~/proj_webrtc/webrtc-checkout/src
   ./out/Default/peerconnection_server
   ```

4. **Run WebRTC Client (Caller)**
   ```bash
   cp ./examples/peerconnection/client/linux/client.cfg ./client.cfg
   vim ./client.cfg
   ```
   Set:
   ```
   disable_gui=true
   is_caller=true
   stun_server_ip=stun.l.google.com
   stun_server_port=19302
   ```
   Then run:
   ```bash
   ./out/Default/peerconnection_client
   ```

5. **Capture Network Traffic**
   ```bash
   cd ~/proj_webrtc/data_pcap
   ifconfig
   sudo tcpdump -i ens4 -G 305 -W 1 -v -w webrtc-1027-gcp.pcap
   ```

---

### UE Machine (Client 2 / Callee)

1. **Virtual Camera Setup**
   ```bash
   cd ~/fanyi/proj_webrtc/webrtc-cellular-measurements/zoom_testbed
   sudo modprobe -r v4l2loopback
   sudo modprobe v4l2loopback card_label="Virtual Camera 1" exclusive_caps=1
   ffmpeg -stream_loop -1 -re -i ./raw_video/Zoom1_1080p_barcode_5min.mp4      -vf scale=1920:1080 -pix_fmt yuyv422 -vcodec rawvideo -threads 2      -f v4l2 /dev/video0
   ```

2. **Run WebRTC Client (Callee)**
   ```bash
   cd ~/fanyi/proj_webrtc/webrtc-checkout/src
   cp ./examples/peerconnection/client/linux/client.cfg ./client.cfg
   vim ./client.cfg
   ```
   Set:
   ```
   disable_gui=true
   is_caller=false
   stun_server_ip=stun.l.google.com
   stun_server_port=19302
   ```
   Then run:
   ```bash
   ./out/Default/peerconnection_client
   ```

3. **Capture Network Traffic**
   ```bash
   cd ~/fanyi/proj_webrtc/data_webrtc/data_exp1027
   ifconfig
   sudo tcpdump -i enx56ebc6769c58 -G 605 -W 1 -v -w webrtc-1027-ue.pcap
   ```

---

## 🤖 Experiment Automation

### 1. Automated WebRTC Experiment (GCP)
```bash
ssh fanyi@34.21.77.56
cd ~/proj_webrtc/webrtc-cellular-measurements/webrtc_testbed
python3 gcp_commands.py -f 0509 -t 1800
```

### 2. Automated WebRTC Experiment (UE)
```bash
cd ~/fanyi/proj_webrtc/webrtc-cellular-measurements/webrtc_testbed
conda activate webrtc_testbed
ping -i 1 google.com  # Reserve RNTI
python ue_desktop_commands.py -f 0415 -t 300 -c 1
```
Options:
- `-c 0`: use FFmpeg virtual camera  
- `-c 1`: use OBS or physical webcam

### 3. NR-Scope Integration
Follow the [NR-Scope guide](https://github.com/PrincetonUniversity/NR-Scope) for real-time 5G RNTI and DCILog collection.

---

## 📊 Post-Processing and Analysis

### 1. Data Collection
From GCP:
```bash
cd ~/fanyi/proj_webrtc/webrtc-cellular-measurements/webrtc_testbed
./collect_data_gcp_tmobile.sh -f 0509
```

From Laptop:
```
/home/paws/video/output2.ivf
/home/paws/video/output2.meta
/home/paws/fanyi/proj_webrtc/data_webrtc/data_exp0404/
```

### 2. Parse NR-Scope Logs (MATLAB)
```matlab
find_activeRNTI_5G.m
process_5g_nrscope.m
```

### 3. Parse WebRTC PCAPs
```bash
cd ~/fanyi/proj_webrtc/webrtc-cellular-measurements/build/release
./rtp_pkts --in <input_ue.pcap> --out <output_ue.csv>
./rtp_pkts --in <input_gcp.pcap> --out <output_gcp.csv>
./rtcp_pkts -i <input.pcap> -t <twcc.csv> -n <nack.csv> -p <port>
```

Merge and sync:
```matlab
merge_csv_webrtc5g
syncAPP_5g_webrtc
```

---

## 🧰 Troubleshooting Tips
- If Xvfb or virtual camera resets after reboot, use:
  ```bash
  (crontab -l 2>/dev/null; echo "@reboot ~/proj_webrtc/webrtc-cellular-measurements/webrtc_testbed/setup-v4l2.sh") | crontab -
  ```
- Always verify time synchronization using `chronyc tracking`.
- For camera issues, reload:
  ```bash
  sudo modprobe -r v4l2loopback && sudo modprobe v4l2loopback
  ```

---

## 📄 Citation
If you use this testbed or dataset in your research, please cite our paper:
```
@inproceedings{domino,
  title     = {Automated, Cross-Layer Root Cause Analysis of 5G Video-Conferencing Quality Degradation},
  author    = {Fan Yi and et al.},
  booktitle = {Proceedings of the ACM Internet Measurement Conference (IMC)},
  year      = {2025}
}
```

---

## 📬 Contact
For questions or collaboration, please contact  
**Fan Yi** – *fanyi@cs.princeton.edu*  
or open an issue in this repository.
