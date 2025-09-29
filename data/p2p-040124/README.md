## 04/01/24 P2P 5G Trace

**Convert to CSV**
```
rtp_pkts --in data/p2p-040124/ue-rtp.pcap --out data/p2p-040124/ue-rtp.csv
 - wrote 94141 lines to data/p2p-040124/ue-rtp.csv
 - skipped 0 lines

rtp_pkts --in data/p2p-040124/sink-rtp.pcap --out data/p2p-040124/sink-rtp.csv
 - wrote 94041 lines to data/p2p-040124/sink-rtp.csv
 - skipped 0 lines
```

**Source-side SDP**
```
v=0
o=- 3343104124323927234 2 IN IP4 127.0.0.1
s=-
t=0 0
a=group:BUNDLE 0
a=extmap-allow-mixed
a=msid-semantic: WMS
m=video 33197 RTP/AVPF 45 46
c=IN IP4 192.168.1.23
a=rtcp:9 IN IP4 0.0.0.0
a=candidate:1363375312 1 udp 2122260224 192.168.45.55 33197 typ host generation 0 network-id 1 network-cost 50
a=candidate:1346569974 1 udp 1686052608 192.168.1.23 33197 typ srflx raddr 192.168.45.55 rport 33197 generation 0 network-id 1 network-cost 50
a=candidate:797742664 1 tcp 1518280448 192.168.45.55 9 typ host tcptype active generation 0 network-id 1 network-cost 50
a=ice-ufrag:OWAj
a=ice-pwd:BOK5K/9ZKihlo+fVL32XSo71
a=ice-options:trickle
a=mid:0
a=extmap:1 urn:ietf:params:rtp-hdrext:toffset
a=extmap:2 http://www.webrtc.org/experiments/rtp-hdrext/abs-send-time
a=extmap:3 urn:3gpp:video-orientation
a=extmap:4 http://www.ietf.org/id/draft-holmer-rmcat-transport-wide-cc-extensions-01
a=extmap:5 http://www.webrtc.org/experiments/rtp-hdrext/playout-delay
a=extmap:6 http://www.webrtc.org/experiments/rtp-hdrext/video-content-type
a=extmap:7 http://www.webrtc.org/experiments/rtp-hdrext/video-timing
a=extmap:8 http://www.webrtc.org/experiments/rtp-hdrext/color-space
a=extmap:9 urn:ietf:params:rtp-hdrext:sdes:mid
a=extmap:10 urn:ietf:params:rtp-hdrext:sdes:rtp-stream-id
a=extmap:11 urn:ietf:params:rtp-hdrext:sdes:repaired-rtp-stream-id
a=extmap:14 https://aomediacodec.github.io/av1-rtp-spec/#dependency-descriptor-rtp-header-extension
a=sendonly
a=msid:- 4206925d-d0b3-454e-846f-d3e00a1f2844
a=rtcp-mux
a=rtcp-rsize
a=rtpmap:45 AV1/90000
a=rtcp-fb:45 goog-remb
a=rtcp-fb:45 transport-cc
a=rtcp-fb:45 ccm fir
a=rtcp-fb:45 nack
a=rtcp-fb:45 nack pli
a=rtpmap:46 rtx/90000
a=fmtp:46 apt=45
a=ssrc-group:FID 1410633866 3945877321
a=ssrc:1410633866 cname:28yYCOPIGm/KeKN0
a=ssrc:1410633866 msid:- 4206925d-d0b3-454e-846f-d3e00a1f2844
a=ssrc:3945877321 cname:28yYCOPIGm/KeKN0
a=ssrc:3945877321 msid:- 4206925d-d0b3-454e-846f-d3e00a1f2844
```