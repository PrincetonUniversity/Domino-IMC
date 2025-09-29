# Zoom Experiment 05/27/24

* 4G
* mostly useful for downlink, screen capture was at UE



(1) Filter Core Packets

```bash
tshark -r zoom-0527-core.pcap -Y '((udp.dstport == 8801 && ip.ttl == 64) || (udp.srcport == 8801 && ip.ttl == 45)) && !gtp' -w zoom-0527-core-filter.pcap
```

(2) Extract Flows and RTP Packets

```bash
export ZOOM_TOOLS=$HOME/src/research/zoom-analysis/build/release
```

```bash
$ZOOM_TOOLS/zoom_flows -i zoom-0527-ue.pcap -f flows-ue.csv -z zoom-0527-ue.zpkt
- input files: 1
- total pkts: 91315
- zoom pkts: 91297
- zoom flows: 16
- runtime [s]: 0.038389
- wrote flow summary to flows-ue.csv
- wrote 84089 filtered packets to zoom-0527-ue.zpkt
```

```bash
$ZOOM_TOOLS/zoom_flows -i zoom-0527-core-filter.pcap -f flows-core.csv -z zoom-0527-core.zpkt
- input files: 1
- total pkts: 83868
- zoom pkts: 83868
- zoom flows: 6
- runtime [s]: 0.047628
- wrote flow summary to flows-core.csv
- wrote 83868 filtered packets to zoom-0527-core.zpkt
```

```bash
$ZOOM_TOOLS/zoom_rtp -i zoom-0527-ue.zpkt -p zoom-0527-ue-pkts.csv -f zoom-0527-ue-frames.csv
- 84089 packets in trace
- pkts: 84089 packets
- runtime [s]: 0.365461
- wrote packets to zoom-0527-ue-pkts.csv
- wrote frames to zoom-0527-ue-frames.csv
```

```bash
$ZOOM_TOOLS/zoom_rtp -i zoom-0527-core.zpkt -p zoom-0527-core-pkts.csv -f zoom-0527-core-frames.csv
- 83868 packets in trace
- pkts: 83868 packets
- runtime [s]: 0.3641
- wrote packets to zoom-0527-core-pkts.csv
- wrote frames to zoom-0527-core-frames.csv
```
