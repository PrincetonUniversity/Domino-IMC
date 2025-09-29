from scapy.all import *
import time

# Set the destination IP address (receiver's IP)
dst_ip = "192.168.1.5"  # Replace with the actual receiver's IP address

# Set the packet size in bytes
packet_size = 1000

# Set the throughput values for each 5-second interval (in Mbps)
throughputs = [2.5, 5, 10, 20, 30, 40]

def generate_burst(throughput, seq_start):
    # Calculate the number of packets to send in each burst
    # send the packets in the thrpt for 50ms
    packets_per_burst = int((throughput * 1000000) / (packet_size * 8) * 0.05)
    burst = []
    for i in range(packets_per_burst):
        seq_num = seq_start + i
        packet = Ether() / IP(dst=dst_ip) / ICMP(seq=seq_num) / ("X" * (packet_size - 42))  # Subtract Ethernet header size
        burst.append(packet)
    return burst, seq_start + packets_per_burst

def send_burst(burst):
    # Send the burst of packets using sendpfast()
    sendpfast(burst, pps=4500, loop=0, iface="enx22725be6d023")  # Set loop=0 to send the burst only once
    # sendp(burst, iface="enx22725be6d023", inter=0.00001, verbose=0)

def main():
    seq_num = 0
    cycle_count = 0

    while cycle_count < 4:  # Run for 4 cycles
        for throughput in throughputs:
            # Generate the burst of packets
            burst, seq_num = generate_burst(throughput, seq_num)
            
            interval_start_time = time.time()
            while time.time() - interval_start_time < 5:  # Run for 5 seconds
                burst_start_time = time.time()
                send_burst(burst)
                burst_end_time = time.time()
                burst_duration = burst_end_time - burst_start_time
                # send burst every 200ms
                remaining_time = 0.2 - burst_duration
                #print(f"remming time: {remaining_time*1000} ms")
                if remaining_time > 0:
                    time.sleep(remaining_time)
            
            print(f"Sent packets with throughput: {throughput} Mbps")
        
        cycle_count += 1
        print(f"Completed cycle {cycle_count} of sending packets")
        print("---")

    print("Script execution completed.")

if __name__ == "__main__":
    main()
