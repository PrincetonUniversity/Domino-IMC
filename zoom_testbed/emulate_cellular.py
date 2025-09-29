# usage: python3 emulate_cellular.py -f network_capacity.csv -i enp0s31f6 -d ul

import time
import subprocess
import csv
import argparse

def set_egress_traffic(capacity, delay, iface):
    # Delete existing qdisc for egress (outbound) traffic
    subprocess.run(["sudo", "tc", "qdisc", "del", "dev", iface, "root"], stderr=subprocess.DEVNULL)

    # Add new qdisc with given capacity and delay for egress traffic
    subprocess.run([
        "sudo", "tc", "qdisc", "replace", "dev", iface, "root", "tbf", 
        "rate", f"{capacity}mbit", 
        "burst", "64kbit", 
        "latency", "10000ms",
        "limit", "100000000"  # unit: bytes, (100 MB)
    ])
    
    # Add netem qdisc for network emulation
    subprocess.run([
        "sudo", "tc", "qdisc", "replace", "dev", iface, "parent", "root", "handle", "10:", "netem", 
        "delay", f"{delay}ms"
    ])

def set_ingress_traffic_redirection(iface):
    # Set up the ifb device if not already done
    subprocess.run(["sudo", "modprobe", "ifb"], stderr=subprocess.DEVNULL)
    subprocess.run(["sudo", "ip", "link", "add", "ifb0", "type", "ifb"], stderr=subprocess.DEVNULL)
    subprocess.run(["sudo", "ip", "link", "set", "up", "dev", "ifb0"], stderr=subprocess.DEVNULL)

    # Redirect ingress traffic to the ifb device
    subprocess.run(["sudo", "tc", "qdisc", "replace", "dev", iface, "handle", "ffff:", "ingress"], stderr=subprocess.DEVNULL)
    subprocess.run(["sudo", "tc", "filter", "replace", "dev", iface, "parent", "ffff:", "protocol", "ip", "u32", "match", "u32", "0", "0", "flowid", "1:1", "action", "mirred", "egress", "redirect", "dev", "ifb0"], stderr=subprocess.DEVNULL)

def set_ingress_traffic(capacity, delay):
    # Delete existing qdisc for ingress (download) traffic on ifb0
    subprocess.run(["sudo", "tc", "qdisc", "del", "dev", "ifb0", "root"], stderr=subprocess.DEVNULL)

    # Add new qdisc with given capacity and delay for ifb0 (ingress traffic)
    subprocess.run([
        "sudo", "tc", "qdisc", "replace", "dev", "ifb0", "root", "tbf", 
        "rate", f"{capacity}mbit", 
        "burst", "64kbit", 
        "latency", "10000ms",
        "limit", "100000000"  # unit: bytes, (100 MB)
    ])
    
    # Add netem qdisc for network emulation
    subprocess.run([
        "sudo", "tc", "qdisc", "replace", "dev", "ifb0", "parent", "root", "handle", "10:", "netem", 
        "delay", f"{delay}ms"
    ])

def main():
    parser = argparse.ArgumentParser(description="Network traffic control script.")
    parser.add_argument('-f', '--file', required=True, help='Network capacity data file name')
    parser.add_argument('-i', '--interface', required=True, help='Network interface name')
    parser.add_argument('-d', '--direction', required=True, choices=['ul', 'dl'], help='Direction of traffic control (ul for upload, dl for download)')
    
    args = parser.parse_args()

    data_file = args.file
    iface = args.interface
    direction = args.direction

    # Initialize redirection only once
    if direction == 'dl':
        set_ingress_traffic_redirection(iface)

    previous_timestamp = None
    with open(data_file, newline='') as csvfile:
        reader = csv.DictReader(csvfile)
        for row in reader:
            timestamp = float(row['timestamp'])
            capacity = float(row['capacity'])
            delay = int(row['delay'])

            if previous_timestamp is not None:
                sleep_time = (timestamp - previous_timestamp) / 1000.0  # Convert to seconds
                
                t1 = time.time()
                if direction == 'ul':
                    set_egress_traffic(capacity, delay, iface)
                elif direction == 'dl':
                    set_ingress_traffic(capacity, delay)
                t2 = time.time()

                processing_time = t2 - t1
                remaining_sleep_time = sleep_time - processing_time

                if remaining_sleep_time > 0:
                    time.sleep(remaining_sleep_time)
            
            print(f"Current timestamp: {timestamp}")
            previous_timestamp = timestamp

if __name__ == "__main__":
    main()
