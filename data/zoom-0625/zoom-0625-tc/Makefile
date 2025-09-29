
EXPERIMENT = zoom-0625-tc
ZOOM_TOOLS = $(HOME)/src/research/zoom-analysis/build/release
UTIL_DIR   = ../../util

all: zoom

zoom: $(EXPERIMENT)-sender-pkts.csv $(EXPERIMENT)-receiver-pkts.csv

# sender packets:

$(EXPERIMENT)-sender.zpkt: $(EXPERIMENT)-sender.pcap
	$(ZOOM_TOOLS)/zoom_flows -i $< -z $@

$(EXPERIMENT)-sender-pkts.csv: $(EXPERIMENT)-sender.zpkt
	$(ZOOM_TOOLS)/zoom_rtp -i $< -p $@ -f $(EXPERIMENT)-sender-frames.csv

# receiver packets:

$(EXPERIMENT)-receiver.zpkt: $(EXPERIMENT)-receiver.pcap
	$(ZOOM_TOOLS)/zoom_flows -i $< -f $(EXPERIMENT)-receiver-flows.csv -z $@

$(EXPERIMENT)-receiver-pkts.csv: $(EXPERIMENT)-receiver.zpkt
	$(ZOOM_TOOLS)/zoom_rtp -i $< -p $@ -f $(EXPERIMENT)-receiver-frames.csv

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
	$(RM) $(EXPERIMENT)-join-pkts-up-seqn.csv
	$(RM) $(EXPERIMENT)-join-pkts-up.csv
	$(RM) $(EXPERIMENT)-pkts-join-up.csv
	$(RM) $(EXPERIMENT)-receiver-framelog.csv
	$(RM) $(EXPERIMENT)-receiver-frames.csv
	$(RM) $(EXPERIMENT)-receiver-pkts.csv
	$(RM) $(EXPERIMENT)-receiver.zpkt
	$(RM) $(EXPERIMENT)-sender-flows.csv
	$(RM) $(EXPERIMENT)-sender-framelog.csv
	$(RM) $(EXPERIMENT)-sender-frames.csv
	$(RM) $(EXPERIMENT)-sender-pkts.csv
	$(RM) $(EXPERIMENT)-sender.zpkt
	$(RM) $(EXPERIMENT)-summary.html 
	$(RM) $(EXPERIMENT)-summary.pdf

.PHONY: clean
