from scapy.all import *
from scapy.utils import PcapWriter
import time

pkts = []
ts = 0
burst_size = 100
seq = 0

pkt_template = Ether(dst = "00:00:00:00:00:00", src = "00:00:00:00:00:00")/ \
               IP(dst = "10.0.0.1", src = "10.0.0.0")

for i in range(1, 100):

    pkt_count = int(burst_size / 1400)
    rmdr = burst_size % 1400

    print (" - seq =",seq,"burst size =",burst_size)

    for j in range(pkt_count):
        seq += 1
        pkt = pkt_template / ICMP(seq = seq) / (b"P"*(1400-42))
        pkt.time = ts
        pkts.append(pkt)

    if (rmdr > 0):
        seq += 1
        pkt = pkt_template / ICMP(seq = seq) / (b"P"*(rmdr-42))
        pkt.time = ts
        pkts.append(pkt)

    ts += 0.03
    burst_size += 100

wrpcap("burst.pcap", pkts)
