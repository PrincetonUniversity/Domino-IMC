
EXPERIMENT = zoom-0625-5g
ZOOM_TOOLS = $(HOME)/src/research/zoom-analysis/build/release
UTIL_DIR   = ../../util
ICMP_PKTS = ../../../build/icmp_pkts

# $(EXPERIMENT)-summary.html: summary.Rmd \
# 	$(EXPERIMENT)-sender-pkts.csv $(EXPERIMENT)-core-pkts.csv $(EXPERIMENT)-receiver-pkts.csv \
# 	$(EXPERIMENT)-sender-frames.csv $(EXPERIMENT)-receiver-frames.csv $(EXPERIMENT)-core-frames.csv \
# 	$(EXPERIMENT)-ssim.csv $(EXPERIMENT)-join-pkts-up-seqn.csv \
# 	$(EXPERIMENT)-receiver-framelog.csv $(EXPERIMENT)-sender-framelog.csv
# 	Rscript -e 'rmarkdown::render("$<")'

all: ping zoom

zoom: $(EXPERIMENT)-sender-pkts.csv $(EXPERIMENT)-core-pkts.csv $(EXPERIMENT)-receiver-pkts.csv
ping: $(EXPERIMENT)-sender-ping.csv $(EXPERIMENT)-core-ping.csv $(EXPERIMENT)-receiver-ping.csv

# sender packets:

$(EXPERIMENT)-sender.zpkt: $(EXPERIMENT)-sender.pcap
	$(ZOOM_TOOLS)/zoom_flows -i $< -z $@

$(EXPERIMENT)-sender-pkts.csv: $(EXPERIMENT)-sender.zpkt
	$(ZOOM_TOOLS)/zoom_rtp -i $< -p $@ -f $(EXPERIMENT)-sender-frames.csv

$(EXPERIMENT)-sender-ping.csv: $(EXPERIMENT)-sender.pcap
	$(ICMP_PKTS) -i $< -o $@

# core packets:

$(EXPERIMENT)-core-filter.pcap: $(EXPERIMENT)-core.pcap
	tshark -r $< -Y 'udp.dstport == 8801 && ip.ttl == 63 && !gtp' -w $@

$(EXPERIMENT)-core.zpkt: $(EXPERIMENT)-core-filter.pcap
	$(ZOOM_TOOLS)/zoom_flows -i $< -f $(EXPERIMENT)-core-flows.csv -z $@

$(EXPERIMENT)-core-pkts.csv: $(EXPERIMENT)-core.zpkt
	$(ZOOM_TOOLS)/zoom_rtp -i $< -p $@ -f $(EXPERIMENT)-core-frames.csv

$(EXPERIMENT)-core-ping.csv: $(EXPERIMENT)-core.pcap
	$(ICMP_PKTS) -i $< -o $@

# receiver packets:

$(EXPERIMENT)-receiver.zpkt: $(EXPERIMENT)-receiver.pcap
	$(ZOOM_TOOLS)/zoom_flows -i $< -f $(EXPERIMENT)-receiver-flows.csv -z $@

$(EXPERIMENT)-receiver-pkts.csv: $(EXPERIMENT)-receiver.zpkt
	$(ZOOM_TOOLS)/zoom_rtp -i $< -p $@ -f $(EXPERIMENT)-receiver-frames.csv

$(EXPERIMENT)-receiver-ping.csv: $(EXPERIMENT)-receiver.pcap
	$(ICMP_PKTS) -i $< -o $@

# joined packets:

$(EXPERIMENT)-join-pkts-up.csv: join.Rmd $(EXPERIMENT)-sender-pkts.csv $(EXPERIMENT)-core-pkts.csv
	Rscript -e 'rmarkdown::render("$<")'

$(EXPERIMENT)-join-pkts-up-seqn.csv: $(EXPERIMENT)-join-pkts-up.csv
	$(UTIL_DIR)/add-sequence.py $< $@
	
# frame logs:

$(EXPERIMENT)-sender-framelog.csv: $(EXPERIMENT)-sender-framelog.txt
	$(UTIL_DIR)/parse-tx-framelog.py $< > $@

$(EXPERIMENT)-receiver-framelog.csv: $(EXPERIMENT)-receiver-framelog.txt
	$(UTIL_DIR)/parse-rx-framelog.py $< > $@

clean:
	$(RM) $(EXPERIMENT)-core-filter.pcap
	$(RM) $(EXPERIMENT)-core-flows.csv
	$(RM) $(EXPERIMENT)-core-frames.csv
	$(RM) $(EXPERIMENT)-core-pkts.csv
	$(RM) $(EXPERIMENT)-core.zpkt
	$(RM) $(EXPERIMENT)-join-pkts-up-seqn.csv
	$(RM) $(EXPERIMENT)-join-pkts-up.csv
	$(RM) $(EXPERIMENT)-pkts-join-up.csv
	$(RM) $(EXPERIMENT)-receiver-framelog.csv
	$(RM) $(EXPERIMENT)-receiver-frames.csv
	$(RM) $(EXPERIMENT)-receiver-ping.csv
	$(RM) $(EXPERIMENT)-receiver-pkts.csv
	$(RM) $(EXPERIMENT)-receiver.zpkt
	$(RM) $(EXPERIMENT)-sender-flows.csv
	$(RM) $(EXPERIMENT)-sender-framelog.csv
	$(RM) $(EXPERIMENT)-sender-frames.csv
	$(RM) $(EXPERIMENT)-sender-ping.csv
	$(RM) $(EXPERIMENT)-sender-pkts.csv
	$(RM) $(EXPERIMENT)-sender.zpkt
	$(RM) $(EXPERIMENT)-summary.html 
	$(RM) $(EXPERIMENT)-summary.pdf

.PHONY: clean
