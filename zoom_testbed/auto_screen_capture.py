import subprocess
import re
import time
import argparse
import threading
import psutil
from datetime import datetime
import csv
import os

def get_window_info(window_name):
    # Run xwininfo command to get the window information
    result = subprocess.run(['xwininfo', '-name', window_name], stdout=subprocess.PIPE)
    output = result.stdout.decode()

    # Extract the necessary values using regular expressions
    width = re.search(r'Width:\s+(\d+)', output).group(1)
    height = re.search(r'Height:\s+(\d+)', output).group(1)
    x_offset_match = re.search(r'Absolute upper-left X:\s+(-?\d+)', output)
    x_offset = int(x_offset_match.group(1))
    y_offset = re.search(r'Absolute upper-left Y:\s+(\d+)', output).group(1)

    return width, height, x_offset, y_offset

def resize_window(window_name, width, height):
    # Get the window ID using wmctrl
    result = subprocess.run(['wmctrl', '-l'], stdout=subprocess.PIPE)
    output = result.stdout.decode()
    window_id = None

    for line in output.splitlines():
        if window_name in line:
            window_id = line.split()[0]
            break

    if window_id:
        # Resize the window using wmctrl
        subprocess.run(['wmctrl', '-i', '-r', window_id, '-e', f'0,-1,-1,{width},{height}'])
    else:
        print(f"Window '{window_name}' not found.")

def move_window(window_name, x, y):
    # Get the window ID using wmctrl
    result = subprocess.run(['wmctrl', '-l'], stdout=subprocess.PIPE)
    output = result.stdout.decode()
    window_id = None

    for line in output.splitlines():
        if window_name in line:
            window_id = line.split()[0]
            break

    if window_id:
        # Move the window using wmctrl
        subprocess.run(['wmctrl', '-i', '-r', window_id, '-e', f'0,{x},{y},-1,-1'])
    else:
        print(f"Window '{window_name}' not found.")

def make_window_fullscreen(window_name):
    # Get the window ID using wmctrl
    result = subprocess.run(['wmctrl', '-l'], stdout=subprocess.PIPE)
    output = result.stdout.decode()
    window_id = None

    for line in output.splitlines():
        if window_name in line:
            window_id = line.split()[0]
            break

    if window_id:
        # Make the window full screen using wmctrl
        subprocess.run(['wmctrl', '-i', '-r', window_id, '-b', 'add,fullscreen'])
    else:
        print(f"Window '{window_name}' not found.")

def bring_window_to_front(window_name):
    # Bring the window to the front using wmctrl
    subprocess.run(['wmctrl', '-a', window_name])

def capture_screen(width, height, x_offset, y_offset, output_file, run_time):
    # Log the current system clock time to frame_log
    frame_log_file = output_file.rsplit('.', 1)[0] + '.txt'
    timestamp = time.time() * 1000  # Convert to milliseconds
    with open(frame_log_file, 'w') as log_file:
        log_file.write(f"Captured start time: {timestamp:.3f}\n")

    # Use the same color space and video codec with original video
    ffmpeg_command = [
        'sudo', 'ffmpeg',
        '-y',  # Automatically overwrite output file
        '-f', 'x11grab',
        '-framerate', '70', # Set the input frame rate
        '-s', f'{width}x{height}',
        '-i', f':0.0+{x_offset},{y_offset}',
        '-t', str(run_time),
        '-vf', 'showinfo',
        '-vcodec', 'libx264',
        '-profile:v', 'high422',  # H.264 high 4:2:2 profile
        '-preset', 'ultrafast',
        '-crf', '0', # achieve lossless compression with the x264 encoder
        '-pix_fmt', 'yuv422p10le',  # Color space
        '-threads', '2',
        '-fps_mode', 'vfr',  # Enable variable frame rate
        output_file
    ]    

    # Run the ffmpeg command and capture the showinfo output
    with open(frame_log_file, 'a') as log_file:
        process = subprocess.Popen(ffmpeg_command, stderr=subprocess.PIPE, universal_newlines=True)
        for line in process.stderr:
            if 'showinfo' in line:
                log_file.write(line)

def capture_network(run_time):
    # Find the network interface starting with 'enx'
    interfaces = psutil.net_if_addrs()
    interface = None
    for iface in interfaces:
        if iface.startswith(('wlp', 'enp0')):
            interface = iface
            break

    if interface is None:
        print("No network interface starting with 'wlp' found.")
        return

    # Get the current date in MMDD format
    current_date = datetime.now().strftime('%m%d')
    output_file = f'../../zoom_data/zoom4g_receiver_{current_date}.pcap'

    tcpdump_command = [
        'sudo', 'tcpdump', '-i', interface, '-v', '-w', output_file
    ]
    
    # Run the tcpdump command for the specified duration
    process = subprocess.Popen(tcpdump_command)
    time.sleep(run_time)
    process.terminate()

def capture_settings_window(width, height, x_offset, y_offset, output_dir, run_time, sleep_time):
    count = 1
    end_time = time.time() + run_time

    if x_offset < 0:
        width = int(width) + int(x_offset) - 70
        x_offset = 70

    # Create the CSV file and write the header
    csv_file = os.path.join(output_dir, 'timestamp.csv')
    with open(csv_file, mode='w', newline='') as file:
        writer = csv.writer(file)
        writer.writerow(['count', 'timestamp'])

    while time.time() < end_time:
        output_file = os.path.join(output_dir, f"{count:04}.jpg")

        # Use scrot to capture the screen
        scrot_command = [
            'scrot',
            '-q', '10',  # Set quality to 10 to reduce file size and CPU usage
            '-a', f'{x_offset},{y_offset},{width},{height}',  # Set the area to capture
            output_file
        ]
        
        subprocess.run(scrot_command)

        # Log the count and timestamp to the CSV file
        timestamp = time.time() * 1000
        with open(csv_file, mode='a', newline='') as file:
            writer = csv.writer(file)
            writer.writerow([count, timestamp])

        count += 1
        time.sleep(sleep_time)


def main():
    parser = argparse.ArgumentParser(description="Capture screen area of Zoom Meeting")
    parser.add_argument('-t', '--time', type=int, required=True, help="Duration for screen capture in seconds")
    parser.add_argument('-o', '--output', type=str, required=True, help="Output filename for the captured video")
    parser.add_argument('-f', '--format', type=str, choices=['720p', '1080p', 'fullscreen'], required=True, help="Screen format: 720p, 1080p, or fullscreen")
    parser.add_argument('--output_fig', type=str, required=True, help="Output directory for the captured images from settings window")
    parser.add_argument('--settings_width', type=int, default=925, help="Width of the settings window")
    parser.add_argument('--settings_height', type=int, default=400, help="Height of the settings window")
    parser.add_argument('--sleep_time', type=int, default=5, help="Sleep time between screenshots of the settings window in seconds")
    args = parser.parse_args()

    window_zoom = "Zoom Meeting"
    window_settings = "Settings"
    run_time = args.time
    output_file = args.output
    output_fig_dir = args.output_fig
    settings_width = args.settings_width
    settings_height = args.settings_height
    sleep_time = args.sleep_time

    if not os.path.exists(output_fig_dir):
        os.makedirs(output_fig_dir)

    # Resize and move the Settings window
    resize_window(window_settings, settings_width, settings_height)
    x_settings = -300
    y_settings = 0
    move_window(window_settings, x_settings, y_settings)

    # Resize and move the Zoom Meeting window
    if args.format == 'fullscreen':
        make_window_fullscreen(window_zoom)
    else:
        if args.format == '720p':
            target_width, target_height = 1280, 720
        elif args.format == '1080p':
            target_width, target_height = 1920, 1080
        resize_window(window_zoom, target_width, target_height)
        move_window(window_zoom, settings_width + x_settings, 0)

    time.sleep(2)

    bring_window_to_front(window_zoom)
    time.sleep(1)

    width, height, x_offset, y_offset = get_window_info(window_zoom)
    swidth, sheight, sx_offset, sy_offset = get_window_info(window_settings)

    screen_thread = threading.Thread(target=capture_screen, args=(width, height, x_offset, y_offset, output_file, run_time))
    network_thread = threading.Thread(target=capture_network, args=(run_time,))
    settings_thread = threading.Thread(target=capture_settings_window, args=(swidth, sheight, sx_offset, sy_offset, output_fig_dir, run_time, sleep_time))

    screen_thread.start()
    network_thread.start()
    settings_thread.start()

    screen_thread.join()
    network_thread.join()
    settings_thread.join()

if __name__ == "__main__":
    main()
