
* Use Wireshark to isolate RTP trafffic: filter for `udp.srcport == 40218 && rtp`

* Extract features from packet traces:

```
rtp_pkts --in data/mediasoup-022624/mediasoup-022624-ue-rtp.pcap --out data/mediasoup-022624/mediasoup-022624-ue.csv
 - wrote 90875 lines to datamediasoup-022624/mediasoup-022624-ue.csv
 - skipped 0 lines
```

```
rtp_pkts --in data/mediasoup-022624/mediasoup-022624-enb-rtp.pcap --out data/mediasoup-022624/mediasoup-022624-enb.csv
 - wrote 90261 lines to data/mediasoup-022624/mediasoup-022624-enb.csv
 - skipped 0 lines
```

```
rtp_pkts --in data/mediasoup-022624/mediasoup-022624-core-rtp.pcap --out data/mediasoup-022624/mediasoup-022624-core.csv
 - wrote 361699 lines to data/mediasoup-022624/mediasoup-022624-core.csv
 - skipped 0 lines
```

```
rtp_pkts --in data/mediasoup-022624/mediasoup-022624-sfu-rtp.pcap --out data/mediasoup-022624/mediasoup-022624-sfu.csv
 - wrote 88391 lines to data/mediasoup-022624/mediasoup-022624-sfu.csv
 - skipped 0 lines
```

* 2nd data set (`udp.dstport == 40047 && rtp`):

```
rtp_pkts --in data/mediasoup-022624/mediasoup-022624-ue-rtp.pcap --out data/mediasoup-022624/mediasoup-022624-ue.csv
 - wrote 77489 lines to data/mediasoup-022624/mediasoup-022624-ue.csv
 - skipped 0 lines
```

```
rtp_pkts --in data/mediasoup-022624/mediasoup-022624-enb-rtp.pcap --out data/mediasoup-022624/mediasoup-022624-enb.csv
 - wrote 74671 lines to data/mediasoup-022624/mediasoup-022624-enb.csv
 - skipped 0 lines
```

```
rtp_pkts --in data/mediasoup-022624/mediasoup-022624-sfu-rtp.pcap --out data/mediasoup-022624/mediasoup-022624-sfu.csv
 - wrote 63488 lines to data/mediasoup-022624/mediasoup-022624-sfu.csv
 - skipped 0 lines
```
