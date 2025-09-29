
EXPERIMENT = zoom-0605-tc-static
ZOOM_TOOLS = $(HOME)/src/research/zoom-analysis/build/release
UTIL_DIR   = ../../util

all: $(EXPERIMENT)-ue-pkts.csv $(EXPERIMENT)-receiver-pkts.csv \
	 $(EXPERIMENT)-ue-frames.csv $(EXPERIMENT)-receiver-frames.csv \
	 $(EXPERIMENT)-ssim.csv $(EXPERIMENT)-receiver-framelog.csv $(EXPERIMENT)-ue-framelog.csv

# zpkt files:

$(EXPERIMENT)-ue.zpkt: $(EXPERIMENT)-ue.pcap
	$(ZOOM_TOOLS)/zoom_flows -i $< -f $(EXPERIMENT)-ue-flows.csv -z $@

$(EXPERIMENT)-receiver.zpkt: $(EXPERIMENT)-receiver.pcap
	$(ZOOM_TOOLS)/zoom_flows -i $< -f $(EXPERIMENT)-receiver-flows.csv -z $@

# pkt csv files:

$(EXPERIMENT)-ue-pkts.csv: $(EXPERIMENT)-ue.zpkt
	$(ZOOM_TOOLS)/zoom_rtp -i $< -p $@ -f $(EXPERIMENT)-ue-frames.csv

$(EXPERIMENT)-receiver-pkts.csv: $(EXPERIMENT)-receiver.zpkt
	$(ZOOM_TOOLS)/zoom_rtp -i $< -p $@ -f $(EXPERIMENT)-receiver-frames.csv

# framelog csv files:

$(EXPERIMENT)-ue-framelog.csv: $(EXPERIMENT)-ue-framelog.txt
	$(UTIL_DIR)/parse-tx-framelog.py $< > $@

$(EXPERIMENT)-receiver-framelog.csv: $(EXPERIMENT)-receiver-framelog.txt
	$(UTIL_DIR)/parse-rx-framelog.py $< > $@

clean:
	$(RM) $(EXPERIMENT)-summary.html 
	$(RM) $(EXPERIMENT)-summary.pdf
	$(RM) $(EXPERIMENT)-ue.zpkt
	$(RM) $(EXPERIMENT)-receiver.zpkt
	$(RM) $(EXPERIMENT)-ue-pkts.csv
	$(RM) $(EXPERIMENT)-receiver-pkts.csv
	$(RM) $(EXPERIMENT)-ue-frames.csv
	$(RM) $(EXPERIMENT)-receiver-frames.csv
	$(RM) $(EXPERIMENT)-receiver-flows.csv
	$(RM) $(EXPERIMENT)-ue-flows.csv
	$(RM) $(EXPERIMENT)-receiver-framelog.csv
	$(RM) $(EXPERIMENT)-ue-framelog.csv

.PHONY: all clean
