# Zoom Experiment 05/12/24


```bash
export ZOOM_TOOLS=$HOME/src/research/zoom-analysis/build/release
```

```bash
$ZOOM_TOOLS/zoom_flows -i zoom-051224-ue.pcap -f flows-ue.csv -z zoom-051224-ue.zpkt
$ZOOM_TOOLS/zoom_flows -i zoom-051224-core-filter.pcap -f flows-core.csv -z zoom-051224-core.zpkt
```

```bash
$ZOOM_TOOLS/zoom_rtp -i zoom-051224-ue.zpkt -p zoom-051224-ue-pkts.csv -f zoom-051224-ue-frames.csv                                                                                                           1
- 241891 packets in trace
- pkts: 241891 packets
- runtime [s]: 0.850095
- wrote packets to zoom-051224-ue-pkts.csv
- wrote frames to zoom-051224-ue-frames.csv

$ZOOM_TOOLS/zoom_rtp -i zoom-051224-core.zpkt -p zoom-051224-core-pkts.csv -f zoom-051224-core-frames.csv
- 484194 packets in trace
- pkts: 484194 packets
- runtime [s]: 1.65503
- wrote packets to zoom-051224-core-pkts.csv
- wrote frames to zoom-051224-core-frames.csv
```

```
!gtp && ((udp.dstport == 8801 && ip.ttl == 64) || (udp.srcport == 8801 && ip.ttl == 45))
```