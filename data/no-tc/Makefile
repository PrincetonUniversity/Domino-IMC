
EXPERIMENT = zoom-no-tc-0623-3
ZOOM_TOOLS = $(HOME)/src/research/zoom-analysis/build/release
UTIL_DIR   = ../../util

all: $(EXPERIMENT)-join-pkts-up-seqn.csv

$(EXPERIMENT)-sender.zpkt: $(EXPERIMENT)-sender.pcap
	$(ZOOM_TOOLS)/zoom_flows -i $< -f $(EXPERIMENT)-sender-flows.csv -z $@

$(EXPERIMENT)-receiver.zpkt: $(EXPERIMENT)-receiver.pcap
	$(ZOOM_TOOLS)/zoom_flows -i $< -f $(EXPERIMENT)-receiver-flows.csv -z $@

$(EXPERIMENT)-sender-pkts.csv: $(EXPERIMENT)-sender.zpkt
	$(ZOOM_TOOLS)/zoom_rtp -i $< -p $@ -f $(EXPERIMENT)-sender-frames.csv

$(EXPERIMENT)-receiver-pkts.csv: $(EXPERIMENT)-receiver.zpkt
	$(ZOOM_TOOLS)/zoom_rtp -i $< -p $@ -f $(EXPERIMENT)-receiver-frames.csv

$(EXPERIMENT)-join-pkts-up.csv: join.Rmd $(EXPERIMENT)-sender-pkts.csv $(EXPERIMENT)-receiver-pkts.csv
	Rscript -e 'rmarkdown::render("$<")'

$(EXPERIMENT)-join-pkts-up-seqn.csv: $(EXPERIMENT)-join-pkts-up.csv
	$(UTIL_DIR)/add-sequence.py $< $@
	
clean:
	$(RM) $(EXPERIMENT)-sender.zpkt
	$(RM) $(EXPERIMENT)-receiver.zpkt
	$(RM) $(EXPERIMENT)-sender-pkts.csv
	$(RM) $(EXPERIMENT)-join-pkts-up.csv
	$(RM) $(EXPERIMENT)-join-pkts-up-seqn.csv
	$(RM) $(EXPERIMENT)-receiver-pkts.csv
	$(RM) $(EXPERIMENT)-sender-flows.csv
	$(RM) $(EXPERIMENT)-pkts-join-up.csv

.PHONY: clean
