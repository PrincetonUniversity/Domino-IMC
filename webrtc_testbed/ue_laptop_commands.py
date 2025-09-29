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
    # Clean up v4l2loopback if we used virtual camera
    if use_virtual_camera:
        try:
            subprocess.run("echo 'wifi' | sudo -S modprobe -r v4l2loopback", shell=True)
        except:
            print("[WARNING] Failed to remove local v4l2loopback module")

def run_command(command):
    process = subprocess.Popen(command, shell=True, preexec_fn=os.setsid)
    return process, process.pid

def get_local_interface():
    result = subprocess.run(['ifconfig'], capture_output=True, text=True)
    for line in result.stdout.split('\n'):
        if 'enx' in line:
            return line.split(':')[0].strip()
    raise Exception("Could not find network interface starting with 'enx'")

# Global list to store process PIDs
running_processes = []
# Global flag for virtual camera usage
use_virtual_camera = False

def run_local_commands(file_number, duration, camera):
    global use_virtual_camera
    use_virtual_camera = (camera == 0)
    
    # Format file number as 4-digit string with leading zeros
    file_number_str = f"{file_number:04d}"
    # Create data directory path
    data_dir = f"/home/paws/fanyi/proj_webrtc/data_webrtc/data_exp{file_number_str}"
    
    try:
        # Set up signal handler for Ctrl+C
        signal.signal(signal.SIGINT, signal_handler)
        signal.signal(signal.SIGTERM, signal_handler)

        # Setup virtual camera if camera==0
        if use_virtual_camera:
            print("[INFO] Setting up virtual camera...")
            
            # 1. Change directory
            print("[INFO] Changing to zoom_testbed directory...")
            os.chdir('/home/paws/fanyi/proj_webrtc/webrtc-cellular-measurements/zoom_testbed')
            
            # 2. Remove v4l2loopback module if loaded
            print("[INFO] Removing v4l2loopback module if loaded...")
            subprocess.run("echo 'wifi' | sudo -S modprobe -r v4l2loopback", shell=True)
            time.sleep(1)
            
            # 3. Load v4l2loopback module with parameters
            print("[INFO] Loading v4l2loopback module with parameters...")
            subprocess.run("echo 'wifi' | sudo -S modprobe v4l2loopback card_label=\"Virtual Camera 1\" exclusive_caps=1", 
                          shell=True, check=True)
            time.sleep(1)
            
            # 4. Start ffmpeg
            print("[INFO] Starting ffmpeg for virtual camera...")
            ffmpeg_cmd = ("ffmpeg -stream_loop -1 -re -i ./raw_video/Zoom1_1080p_barcode_15min.mp4 "
                         "-vf scale=1920:1080 -pix_fmt yuyv422 -vcodec rawvideo -threads 2 "
                         "-f v4l2 /dev/video2")
            ffmpeg_process, ffmpeg_pid = run_command(ffmpeg_cmd)
            running_processes.append(ffmpeg_pid)
        else:
            print("[INFO] Using real camera...")

        # Ensure data directory exists
        os.makedirs(data_dir, exist_ok=True)
        
        # Start CPU usage monitoring with mpstat
        print("[INFO] Starting CPU usage monitoring...")
        mpstat_count = duration + 5  # Add buffer time for monitoring
        mpstat_cmd = f"mpstat -P ALL -o JSON 1 {mpstat_count} > {data_dir}/cpu-2.json"
        mpstat_process, mpstat_pid = run_command(mpstat_cmd)
        running_processes.append(mpstat_pid)

        # Start tcpdump
        print("[INFO] Starting tcpdump...")
        interface = get_local_interface()
        tcpdump_cmd = (f"cd {data_dir} && "
                    f"echo 'wifi' | sudo -S tcpdump -i {interface} -G {duration + 5} -W 1 -v -w "
                    f"webrtc-{file_number_str}-ue.pcap")
        tcpdump_process, tcpdump_pid = run_command(tcpdump_cmd)
        running_processes.append(tcpdump_pid)

        # Start WebRTC Client 2 with output redirected to file with timestamps
        time.sleep(1)
        print("[INFO] Starting WebRTC Client 2...")
        log_file = f"{data_dir}/webrtc-log-2.txt"
        
        # Command that runs the client and pipes output through awk for timestamping
        client_cmd = (f"cd /home/paws/fanyi/proj_webrtc/webrtc-checkout/src && "
                     f"./out/Default/peerconnection_client 2>&1 | "
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
        
        # Move CSV files and SDP files to data directory
        try:
            # Ensure data directory exists
            os.makedirs(data_dir, exist_ok=True)
            
            # Move 17*.csv files
            subprocess.run(f"mv /home/paws/fanyi/proj_webrtc/webrtc-checkout/src/17*.csv {data_dir}/", 
                         shell=True, 
                         check=False)  # Using check=False to prevent exception if no files found
            
            # Move sdp* files
            subprocess.run(f"mv /home/paws/fanyi/proj_webrtc/webrtc-checkout/src/sdp* {data_dir}/", 
                         shell=True, 
                         check=False)
            
            print(f"[INFO] Moved CSV and SDP files to {data_dir}/")
        except Exception as e:
            print(f"[WARNING] Failed to move CSV and SDP files: {e}")

def main():
    parser = argparse.ArgumentParser(description='Run local commands')
    parser.add_argument('-f', type=int, required=True, help='File number for the experiment')
    parser.add_argument('-t', type=int, required=True, help='Duration in seconds')
    parser.add_argument('-c', '--camera', type=int, default=0, choices=[0, 1], 
                       help='Camera type: 0 for virtual camera (default), 1 for real camera')
    args = parser.parse_args()

    run_local_commands(args.f, args.t, args.camera)

if __name__ == "__main__":
    main()