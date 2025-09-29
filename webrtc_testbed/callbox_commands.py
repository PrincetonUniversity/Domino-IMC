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

def run_command(command):
    process = subprocess.Popen(command, shell=True, preexec_fn=os.setsid)
    return process, process.pid

# Global list to store process PIDs
running_processes = []

def run_callbox_commands(file_number, duration):
    try:
        # Set up signal handler for Ctrl+C
        signal.signal(signal.SIGINT, signal_handler)
        signal.signal(signal.SIGTERM, signal_handler)

        # Clean old webrtc logs
        print("[INFO] Cleaning old WebRTC logs...")
        clean_cmd = "echo 'toor' | sudo -S rm -rf /var/log/lte/gnb0_webrtc.log*"
        subprocess.run(clean_cmd, shell=True)

        # Start STUN server
        print("[INFO] Starting STUN server...")
        stun_cmd = ("cd /root/proj_webrtc/stunserver && "
                   "./stunserver --primaryinterface 128.112.92.50 --primaryport 3478")
        stun_process, stun_pid = run_command(stun_cmd)
        running_processes.append(stun_pid)

        # Start tcpdump (duration + 5s buffer for capturing full session)
        file_number_str = f"{file_number:04d}"  # Format as 4-digit number with leading zeros
        print("[INFO] Starting tcpdump...")
        tcpdump_cmd = (f"cd /root/proj_webrtc/data && "
                      f"echo 'toor' | sudo -S tcpdump -i eno1 -G {duration + 5} -W 1 -v -w "
                      f"webrtc-{file_number_str}-core.pcap")
        tcpdump_process, tcpdump_pid = run_command(tcpdump_cmd)
        running_processes.append(tcpdump_pid)

        # Wait for specified duration plus buffer time
        print(f"[INFO] Running for {duration} seconds...")
        time.sleep(duration + 10)

    except Exception as e:
        print(f"[ERROR] An error occurred: {str(e)}")
        raise
    finally:
        # Terminate all processes
        terminate_processes()
        
        # Move webrtc logs to data folder
        print("[INFO] Moving WebRTC logs to data folder...")
        move_cmd1 = "echo 'toor' | sudo -S mv /var/log/lte/gnb0_webrtc.log* /root/proj_webrtc/data/"
        move_cmd2 = "echo 'toor' | sudo -S mv /tmp/gnb0_webrtc.log* /root/proj_webrtc/data/"
        subprocess.run(move_cmd1, shell=True)
        subprocess.run(move_cmd2, shell=True)

def main():
    parser = argparse.ArgumentParser(description='Run Callbox commands')
    parser.add_argument('-f', type=int, required=True, help='File number for the experiment')
    parser.add_argument('-t', type=int, required=True, help='Duration in seconds')
    args = parser.parse_args()

    run_callbox_commands(args.f, args.t)

if __name__ == "__main__":
    main()