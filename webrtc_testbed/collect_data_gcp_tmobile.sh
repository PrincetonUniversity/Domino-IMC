#!/bin/bash

# Function to display usage
usage() {
    echo "Usage: $0 -f <experiment_number>"
    exit 1
}

# Parse command line arguments
while getopts "f:" opt; do
    case $opt in
        f) exp_num="$OPTARG"
        ;;
        *) usage
        ;;
    esac
done

# Check if experiment number is provided
if [ -z "$exp_num" ]; then
    usage
fi

# Create directory structure
data_dir="../../data_webrtc/data_exp${exp_num}"
video_dir="${data_dir}/video"
mkdir -p "$data_dir"
mkdir -p "$video_dir"

echo "Creating directories: $data_dir and $video_dir"

# Collect PCAP files
echo "Collecting PCAP files..."

# Remote GCP PCAP (previously Pegasus)
scp "fanyi@34.21.77.56:/home/fanyi/proj_webrtc/data_pcap/webrtc-${exp_num}-gcp.pcap" "$data_dir/" || echo "Warning: GCP PCAP file not found"

# Collect application data
echo "Collecting application data..."

# Remote CSV files from GCP (previously Pegasus)
scp "fanyi@34.21.77.56:/home/fanyi/proj_webrtc/data_webrtc/data_exp${exp_num}/17*.csv" "$data_dir/" || echo "Warning: Remote CSV files not found"
scp "fanyi@34.21.77.56:/home/fanyi/proj_webrtc/data_webrtc/data_exp${exp_num}/sdp*" "$data_dir/" || echo "Warning: Remote sdp file not found"

# Collect CPU usage data
echo "Collecting CPU usage data..."
scp "fanyi@34.21.77.56:/home/fanyi/proj_webrtc/data_webrtc/data_exp${exp_num}/cpu-1.json" "$data_dir/" || echo "Warning: Remote CPU usage data file not found"

# Collect WebRTC log file
echo "Collecting WebRTC log file..."
scp "fanyi@34.21.77.56:/home/fanyi/proj_webrtc/data_webrtc/data_exp${exp_num}/webrtc-log-1.txt" "$data_dir/" || echo "Warning: Remote WebRTC log file not found"

# Collect video files
echo "Collecting video files..."

# Local video files
mv ~/video/output* "$video_dir/" || echo "Warning: Local video files not found"

# Remote video files from GCP (previously Pegasus)
scp "fanyi@34.21.77.56:~/video/output*" "$video_dir/" || echo "Warning: Remote video files not found"

echo "Data collection complete. Check $data_dir for collected files."

# List collected files
echo -e "\nCollected files:"
ls -R "$data_dir"