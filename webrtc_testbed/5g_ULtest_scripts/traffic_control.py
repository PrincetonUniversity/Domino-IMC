from scapy.all import *
import time

# Set the destination IP address (receiver's IP) and port
dst_ip = "192.168.1.5"  # Replace with the actual receiver's IP address
dst_port = 12345  # Choose a port number

# Set the packet size in bytes
packet_size = 1000

# Set the throughput values for each 5-second interval (in Mbps)
throughputs = [2.5, 5, 10, 20, 30, 40]

def send_burst(throughput, seq_start):
    packets_per_burst = int((throughput * 1000000) / (packet_size * 8) * 0.03)
    burst = []
    for i in range(packets_per_burst):
        seq_num = seq_start + i
        payload = f"Sequence Number: {seq_num}"
        dummy_data = "X" * (packet_size - len(payload) - 28)  # Subtract IP and UDP header sizes
        packet = IP(dst=dst_ip) / UDP(dport=dst_port) / (payload + dummy_data)
        burst.append(packet)
    sendpfast(burst, verbose=0)
    return seq_start + packets_per_burst

def main():
    seq_num = 0
    start_time = time.time()

    while time.time() - start_time < 120:  # Run for 2 minutes (120 seconds)
        for throughput in throughputs:
            interval_start_time = time.time()
            while time.time() - interval_start_time < 5:
                burst_start_time = time.time()
                seq_num = send_burst(throughput, seq_num)
                burst_end_time = time.time()
                burst_duration = burst_end_time - burst_start_time
                remaining_time = 0.03 - burst_duration
                if remaining_time > 0:
                    time.sleep(remaining_time)
            print(f"Sent packets with throughput: {throughput} Mbps")

    print("Completed one cycle of sending packets")
    print("---")
    print("Script execution completed.")

if __name__ == "__main__":
    main()
