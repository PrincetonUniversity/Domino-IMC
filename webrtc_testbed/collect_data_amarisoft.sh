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

# Local UE PCAP
mv ~/fanyi/proj_webrtc/data_webrtc/data_exp${exp_num}/webrtc-${exp_num}-ue.pcap "$data_dir/" || echo "Warning: UE PCAP file not found"

# Remote Core PCAP
scp "root@128.112.92.50:~/proj_webrtc/data/webrtc-${exp_num}-core.pcap" "$data_dir/" || echo "Warning: Core PCAP file not found"

# Remote Core phy/mac logs
scp "root@128.112.92.50:~/proj_webrtc/data/gnb0_webrtc.log*" "$data_dir/" || echo "Warning: Core phy/mac logs not found"

# Remote Pegasus PCAP
scp "fanyi@128.112.92.92:/home/fanyi/proj_webrtc/data_pcap/webrtc-${exp_num}-pegasus.pcap" "$data_dir/" || echo "Warning: Pegasus PCAP file not found"

# # Collect ENB data
# echo "Collecting ENB data..."
# mv ~/Downloads/enb-export.log.zip "$data_dir/" || echo "Warning: ENB export file not found"

# Collect application data
echo "Collecting application data..."

# Local CSV files
mv ~/fanyi/proj_webrtc/webrtc-checkout/src/17*.csv "$data_dir/" || echo "Warning: Local CSV files not found"
mv ~/fanyi/proj_webrtc/webrtc-checkout/src/sdp* "$data_dir/" || echo "Warning: Local sdp file not found"

# Remote CSV files
scp "fanyi@128.112.92.92:/home/fanyi/proj_webrtc/data_webrtc/data_exp${exp_num}/17*.csv" "$data_dir/" || echo "Warning: Remote CSV files not found"
scp "fanyi@128.112.92.92:/home/fanyi/proj_webrtc/data_webrtc/data_exp${exp_num}/sdp*" "$data_dir/" || echo "Warning: Remote sdp file not found"

# Collect CPU usage data
echo "Collecting CPU usage data..."
scp "fanyi@128.112.92.92:/home/fanyi/proj_webrtc/data_webrtc/data_exp${exp_num}/cpu-1.json" "$data_dir/" || echo "Warning: Remote CPU usage data file not found"

# Collect WebRTC log file
echo "Collecting WebRTC log file..."
scp "fanyi@128.112.92.92:/home/fanyi/proj_webrtc/data_webrtc/data_exp${exp_num}/webrtc-log-1.txt" "$data_dir/" || echo "Warning: Remote WebRTC log file not found"

# Collect video files
echo "Collecting video files..."

# Local video files
mv ~/video/output* "$video_dir/" || echo "Warning: Local video files not found"

# Remote video files
scp "fanyi@128.112.92.92:~/video/output*" "$video_dir/" || echo "Warning: Remote video files not found"

echo "Data collection complete. Check $data_dir for collected files."

# List collected files
echo -e "\nCollected files:"
ls -R "$data_dir"