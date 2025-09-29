import subprocess
import argparse
import time
import os
import signal
import sys

def signal_handler(sig, frame):
    print('\nCtrl+C detected. Terminating all processes...')
    terminate_processes()
    sys.exit(0)

def terminate_processes():
    try:
        for pid in running_processes:
            try:
                os.killpg(pid, signal.SIGINT)
                time.sleep(1)  # Give process time to terminate gracefully
                try:
                    os.killpg(pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass  # Process already terminated
            except ProcessLookupError:
                continue
    except Exception as e:
        print(f"Error during cleanup: {e}")
    # Clean up v4l2loopback
    try:
        subprocess.run("echo 'wifi@123' | sudo -S modprobe -r v4l2loopback", shell=True)
    except:
        print("[WARNING] Failed to remove v4l2loopback module")

def run_command(command):
    process = subprocess.Popen(command, shell=True, preexec_fn=os.setsid)
    return process, process.pid

# Global list to store process PIDs
running_processes = []

def run_pegasus_commands(file_number, duration):
    try:
        # Format file number as 4-digit string with leading zeros
        file_number_str = f"{file_number:04d}"
        # Create data directory path
        data_dir = f"/home/fanyi/proj_webrtc/data_webrtc/data_exp{file_number_str}"
        # Create directory if it doesn't exist
        os.makedirs(data_dir, exist_ok=True)
        
        # Set up signal handler for Ctrl+C
        signal.signal(signal.SIGINT, signal_handler)
        signal.signal(signal.SIGTERM, signal_handler)

        # Start CPU usage monitoring with mpstat
        print("[INFO] Starting CPU usage monitoring...")
        mpstat_count = duration + 5  # Add buffer time for monitoring
        mpstat_cmd = f"mpstat -P ALL -o JSON 1 {mpstat_count} > {data_dir}/cpu-1.json"
        mpstat_process, mpstat_pid = run_command(mpstat_cmd)
        running_processes.append(mpstat_pid)

        # Start WebRTC server
        print("[INFO] Starting WebRTC server...")
        server_cmd = ("cd /home/fanyi/proj_webrtc/webrtc-checkout/src && "
                     "./out/Default/peerconnection_server")
        server_process, server_pid = run_command(server_cmd)
        running_processes.append(server_pid)

        # Start virtual camera
        print("[INFO] Starting virtual camera...")
        camera_cmd = ("echo 'wifi@123' | sudo -S bash -c '"
                     "cd /home/fanyi/proj_webrtc/webrtc-cellular-measurements/zoom_testbed && "
                     "modprobe v4l2loopback && "
                     "ffmpeg -stream_loop -1 -re -i ./raw_video/Zoom1_1080p_barcode_15min.mp4 "
                     "-vf scale=1920:1080 -pix_fmt yuyv422 -vcodec rawvideo -threads 2 "
                     "-f v4l2 /dev/video0'")
        camera_process, camera_pid = run_command(camera_cmd)
        running_processes.append(camera_pid)

        # Start tcpdump
        print("[INFO] Starting tcpdump...")
        tcpdump_cmd = (f"cd /home/fanyi/proj_webrtc/data_pcap && "
                      f"echo 'wifi@123' | sudo -S tcpdump -i ens4f0 -G {duration + 5} -W 1 -v -w "
                      f"webrtc-{file_number_str}-pegasus.pcap")
        tcpdump_process, tcpdump_pid = run_command(tcpdump_cmd)
        running_processes.append(tcpdump_pid)

        # Start WebRTC Client 1 with output redirected to file with timestamps
        print("[INFO] Starting WebRTC Client 1...")
        log_file = f"{data_dir}/webrtc-log-1.txt"
        
        # Command that runs the client and pipes output through awk for timestamping
        client_cmd = ("cd /home/fanyi/proj_webrtc/webrtc-checkout/src && "
                     "./out/Default/peerconnection_client 2>&1 | "
                     f"awk '{{ printf(\"%f: %s\\n\", systime(), $0); fflush(); }}' > {log_file}")
        client_process, client_pid = run_command(client_cmd)
        running_processes.append(client_pid)

        # Wait for specified duration plus buffer time
        print(f"[INFO] Running for {duration} seconds...")
        time.sleep(duration + 10)

    except Exception as e:
        print(f"[ERROR] An error occurred: {str(e)}")
        raise
    finally:
        terminate_processes()
        
        # Move CSV files
        try:
            subprocess.run(f"mv /home/fanyi/proj_webrtc/webrtc-checkout/src/17*.csv {data_dir}/", 
                         shell=True, 
                         check=False)  # Using check=False to prevent exception if no files found
            subprocess.run(f"mv /home/fanyi/proj_webrtc/webrtc-checkout/src/sdp* {data_dir}/", 
                         shell=True, 
                         check=False)
            print(f"[INFO] Moved CSV and SDP files to {data_dir}/")        
        except Exception as e:
            print(f"[WARNING] Failed to move CSV files: {e}")


def main():
    parser = argparse.ArgumentParser(description='Run Pegasus commands')
    parser.add_argument('-f', type=int, required=True, help='File number for the experiment')
    parser.add_argument('-t', type=int, required=True, help='Duration in seconds')
    args = parser.parse_args()

    run_pegasus_commands(args.f, args.t)

if __name__ == "__main__":
    main()