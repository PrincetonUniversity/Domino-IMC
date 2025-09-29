"""
ICMP Echo Request Packet Analyzer
--------------------------------

This script analyzes PCAP (packet capture) files and extracts information about ICMP Echo Request 
packets (ping requests). It processes the PCAP file and generates a CSV file containing detailed 
information about each ping request packet.

Features:
- Extracts sequence numbers, packet sizes, timestamps, ICMP types, and source IP addresses
- Processes only ICMP Echo Request packets (type 8)
- Outputs data in an easy-to-analyze CSV format
- Command-line interface for easy automation and integration

Requirements:
- Python 3.x
- scapy library (install using: pip install scapy)
- Sufficient permissions to read PCAP files

Usage:
    python3 process_icmp.py -i <input_pcap_file> -o <output_csv_file>

Arguments:
    -i, --input     Path to the input PCAP file (required)
    -o, --output    Path to the output CSV file (required)

Output CSV Format:
    - Sequence Number: The sequence number of the ICMP packet
    - Packet Size: Total size of the packet in bytes
    - Timestamp: Time when the packet was captured
    - ICMP Type: Type of ICMP packet (will be 8 for Echo Requests)
    - Source IP: IP address of the packet sender

Note: This script requires administrative/root privileges on some systems to process PCAP files.

Author: Fan Yi
Date: 10/31/2024
Version: 1.1
"""

from scapy.all import *
import csv
import argparse

def process_pcap(pcap_file, output_file):
    packets = rdpcap(pcap_file)
    
    with open(output_file, 'w', newline='') as csvfile:
        csv_writer = csv.writer(csvfile)
        csv_writer.writerow(['Sequence Number', 'Packet Size', 'Timestamp', 'ICMP Type', 'Source IP'])
        
        for packet in packets:
            if ICMP in packet and packet[ICMP].type == 8:  # ICMP Echo Request
                seq_num = packet[ICMP].seq
                packet_size = len(packet)
                timestamp = packet.time
                icmp_type = packet[ICMP].type
                source_ip = packet[IP].src  # Extract source IP address
                csv_writer.writerow([seq_num, packet_size, timestamp, icmp_type, source_ip])

def main():
    # Parse command-line arguments
    parser = argparse.ArgumentParser(description='Process PCAP file and extract ICMP Echo Request packet information.')
    parser.add_argument('-i', '--input', required=True, help='Path to the input PCAP file')
    parser.add_argument('-o', '--output', required=True, help='Path to the output CSV file')
    args = parser.parse_args()

    # Process the PCAP file and generate the CSV file
    process_pcap(args.input, args.output)
    print(f"PCAP processing completed. CSV file generated: {args.output}")

if __name__ == "__main__":
    main()