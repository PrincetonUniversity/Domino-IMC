## 04/22/24 - P2P 4G Round Robin Experiment

**Filter RTP:**
```
udp.port == 44799 && rtcp
```

**Convert to RTP packets to CSV:**
```
% build/release/rtp_pkts --in data/p2p-4g-rr-042224/p2p-4g-rr-042224-source-rtp.pcap --out data/p2p-4g-rr-042224/p2p-4g-rr-042224-source-rtp.csv
 - av1_dd: start, tpl_id=0, frame_num=1
   - id=0, spatial_layer_id=0, temporal_layer_id=0, dtis=[ switch switch switch switch ]
   - id=1, spatial_layer_id=0, temporal_layer_id=0, dtis=[ switch switch required required ]
   - id=2, spatial_layer_id=0, temporal_layer_id=1, dtis=[ not-present discardable not-present required ]
   - id=3, spatial_layer_id=1, temporal_layer_id=0, dtis=[ not-present not-present switch switch ]
   - id=4, spatial_layer_id=1, temporal_layer_id=0, dtis=[ not-present not-present switch switch ]
   - id=5, spatial_layer_id=1, temporal_layer_id=1, dtis=[ not-present not-present not-present discardable ]
 - av1_dd: start, tpl_id=6, frame_num=681
   - id=6, spatial_layer_id=0, temporal_layer_id=0, dtis=[ switch switch switch switch ]
   - id=7, spatial_layer_id=0, temporal_layer_id=0, dtis=[ switch switch required required ]
   - id=8, spatial_layer_id=0, temporal_layer_id=1, dtis=[ not-present discardable not-present required ]
   - id=9, spatial_layer_id=1, temporal_layer_id=0, dtis=[ not-present not-present switch switch ]
   - id=10, spatial_layer_id=1, temporal_layer_id=0, dtis=[ not-present not-present switch switch ]
   - id=11, spatial_layer_id=1, temporal_layer_id=1, dtis=[ not-present not-present not-present discardable ]
 - av1_dd: start, tpl_id=12, frame_num=64606
   - id=12, spatial_layer_id=0, temporal_layer_id=0, dtis=[ switch switch switch switch ]
   - id=13, spatial_layer_id=0, temporal_layer_id=0, dtis=[ switch switch required required ]
   - id=14, spatial_layer_id=0, temporal_layer_id=1, dtis=[ not-present discardable not-present required ]
   - id=15, spatial_layer_id=1, temporal_layer_id=0, dtis=[ not-present not-present switch switch ]
   - id=16, spatial_layer_id=1, temporal_layer_id=0, dtis=[ not-present not-present switch switch ]
   - id=17, spatial_layer_id=1, temporal_layer_id=1, dtis=[ not-present not-present not-present discardable ]
 - av1_dd: start, tpl_id=18, frame_num=1905
   - id=18, spatial_layer_id=0, temporal_layer_id=0, dtis=[ switch switch switch switch ]
   - id=19, spatial_layer_id=0, temporal_layer_id=0, dtis=[ switch switch required required ]
   - id=20, spatial_layer_id=0, temporal_layer_id=1, dtis=[ not-present discardable not-present required ]
   - id=21, spatial_layer_id=1, temporal_layer_id=0, dtis=[ not-present not-present switch switch ]
   - id=22, spatial_layer_id=1, temporal_layer_id=0, dtis=[ not-present not-present switch switch ]
   - id=23, spatial_layer_id=1, temporal_layer_id=1, dtis=[ not-present not-present not-present discardable ]
 - wrote 290607 lines to data/p2p-4g-rr-042224/p2p-4g-rr-042224-source-rtp.csv
 - skipped 0 lines
```

```
% build/release/rtp_pkts --in data/p2p-4g-rr-042224/p2p-4g-rr-042224-sink-rtp.pcap --out data/p2p-4g-rr-042224/p2p-4g-rr-042224-sink-rtp.csv
 - wrote 289175 lines to data/p2p-4g-rr-042224/p2p-4g-rr-042224-sink-rtp.csv
 - skipped 0 lines
```

**Session Description:**
```sdp
v=0
o=- 8105327118292234833 2 IN IP4 127.0.0.1
s=-
t=0 0
a=group:BUNDLE 0 1
a=extmap-allow-mixed
a=msid-semantic: WMS 1ee7c99e-52f8-4a36-b138-4f7671a55e41 27fdfa15-5dfd-4153-b94e-a07e1bf6a4c7

m=audio 44799 RTP/AVPF 111
c=IN IP4 192.168.68.7
a=rtcp:9 IN IP4 0.0.0.0
a=candidate:1198817089 1 udp 2113937151 0d9a41f6-5151-4d03-8060-7f1a9eda2609.local 44799 typ host generation 0 network-cost 999
a=candidate:1790313364 1 udp 1677729535 192.168.68.7 44799 typ srflx raddr 0.0.0.0 rport 0 generation 0 network-cost 999
a=ice-ufrag:RRoX
a=ice-pwd:up2hnbP8Q63TwVMEzPb1UHjl
a=ice-options:trickle
a=mid:0
a=extmap:1 urn:ietf:params:rtp-hdrext:ssrc-audio-level
a=extmap:2 http://www.webrtc.org/experiments/rtp-hdrext/abs-send-time
a=extmap:3 http://www.ietf.org/id/draft-holmer-rmcat-transport-wide-cc-extensions-01
a=extmap:4 urn:ietf:params:rtp-hdrext:sdes:mid
a=recvonly
a=msid:27fdfa15-5dfd-4153-b94e-a07e1bf6a4c7 d63db058-89a5-4f6a-bb0d-9751e60be621
a=rtcp-mux
a=rtpmap:111 opus/48000/2
a=rtcp-fb:111 transport-cc
a=fmtp:111 minptime=10;useinbandfec=1
a=ssrc:781043086 cname:c/wBcWq6OJwTEU14

m=video 9 RTP/AVPF 45 46
c=IN IP4 0.0.0.0
a=rtcp:9 IN IP4 0.0.0.0
a=ice-ufrag:RRoX
a=ice-pwd:up2hnbP8Q63TwVMEzPb1UHjl
a=ice-options:trickle
a=mid:1
a=extmap:14 urn:ietf:params:rtp-hdrext:toffset
a=extmap:2 http://www.webrtc.org/experiments/rtp-hdrext/abs-send-time
a=extmap:13 urn:3gpp:video-orientation
a=extmap:3 http://www.ietf.org/id/draft-holmer-rmcat-transport-wide-cc-extensions-01
a=extmap:5 http://www.webrtc.org/experiments/rtp-hdrext/playout-delay
a=extmap:6 http://www.webrtc.org/experiments/rtp-hdrext/video-content-type
a=extmap:7 http://www.webrtc.org/experiments/rtp-hdrext/video-timing
a=extmap:8 http://www.webrtc.org/experiments/rtp-hdrext/color-space
a=extmap:4 urn:ietf:params:rtp-hdrext:sdes:mid
a=extmap:10 urn:ietf:params:rtp-hdrext:sdes:rtp-stream-id
a=extmap:11 urn:ietf:params:rtp-hdrext:sdes:repaired-rtp-stream-id
a=extmap:12 https://aomediacodec.github.io/av1-rtp-spec/#dependency-descriptor-rtp-header-extension
a=recvonly
a=msid:1ee7c99e-52f8-4a36-b138-4f7671a55e41 e8f5e24a-ddba-4329-aa22-9512ca9c0eef
a=rtcp-mux
a=rtcp-rsize
a=rtpmap:45 AV1/90000
a=rtcp-fb:45 goog-remb
a=rtcp-fb:45 transport-cc
a=rtcp-fb:45 ccm fir
a=rtcp-fb:45 nack
a=rtcp-fb:45 nack pli
a=fmtp:45 level-idx=5;profile=0;tier=0
a=rtpmap:46 rtx/90000
a=fmtp:46 apt=45
a=ssrc-group:FID 1134149055 1131857630
a=ssrc:1134149055 cname:c/wBcWq6OJwTEU14
a=ssrc:1131857630 cname:c/wBcWq6OJwTEU14
```