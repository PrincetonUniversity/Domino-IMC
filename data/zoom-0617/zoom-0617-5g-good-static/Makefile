
EXPERIMENT = zoom-0617-5g-good-static
ZOOM_TOOLS = $(HOME)/src/research/zoom-analysis/build/release
UTIL_DIR   = ../../util

$(EXPERIMENT)-summary.html: summary.Rmd \
	$(EXPERIMENT)-sender-pkts.csv $(EXPERIMENT)-core-pkts.csv $(EXPERIMENT)-receiver-pkts.csv \
	$(EXPERIMENT)-sender-frames.csv $(EXPERIMENT)-receiver-frames.csv $(EXPERIMENT)-core-frames.csv \
	$(EXPERIMENT)-ssim.csv $(EXPERIMENT)-join-pkts-up.csv \
	$(EXPERIMENT)-receiver-framelog.csv $(EXPERIMENT)-sender-framelog.csv
	Rscript -e 'rmarkdown::render("$<")'

$(EXPERIMENT)-summary.pdf: summary.Rmd $(EXPERIMENT)-sender-pkts.csv $(EXPERIMENT)-core-pkts.csv \
	$(EXPERIMENT)-sender-frames.csv $(EXPERIMENT)-core-frames.csv $(EXPERIMENT)-ssim.csv
	Rscript -e 'rmarkdown::render("$<")'

$(EXPERIMENT)-core-filter.pcap: $(EXPERIMENT)-core.pcap
	tshark -r $< -Y '((udp.dstport == 8801 && ip.ttl == 64) || (udp.srcport == 8801 && ip.ttl == 45)) && !gtp' -w $@

$(EXPERIMENT)-sender.zpkt: $(EXPERIMENT)-sender.pcap
	$(ZOOM_TOOLS)/zoom_flows -i $< -f $(EXPERIMENT)-sender-flows.csv -z $@

$(EXPERIMENT)-core.zpkt: $(EXPERIMENT)-core-filter.pcap
	$(ZOOM_TOOLS)/zoom_flows -i $< -f $(EXPERIMENT)-core-flows.csv -z $@

$(EXPERIMENT)-receiver.zpkt: $(EXPERIMENT)-receiver.pcap
	$(ZOOM_TOOLS)/zoom_flows -i $< -f $(EXPERIMENT)-receiver-flows.csv -z $@

$(EXPERIMENT)-sender-pkts.csv: $(EXPERIMENT)-sender.zpkt
	$(ZOOM_TOOLS)/zoom_rtp -i $< -p $@ -f $(EXPERIMENT)-sender-frames.csv

$(EXPERIMENT)-core-pkts.csv: $(EXPERIMENT)-core.zpkt
	$(ZOOM_TOOLS)/zoom_rtp -i $< -p $@ -f $(EXPERIMENT)-core-frames.csv

$(EXPERIMENT)-receiver-pkts.csv: $(EXPERIMENT)-receiver.zpkt
	$(ZOOM_TOOLS)/zoom_rtp -i $< -p $@ -f $(EXPERIMENT)-receiver-frames.csv

$(EXPERIMENT)-join-pkts-up.csv: join.Rmd $(EXPERIMENT)-sender-pkts.csv $(EXPERIMENT)-core-pkts.csv
	Rscript -e 'rmarkdown::render("$<")'

$(EXPERIMENT)-join-pkts-up-seqn.csv: $(EXPERIMENT)-join-pkts-up.csv
	$(UTIL_DIR)/add-sequence.py $< $@

$(EXPERIMENT)-sender-framelog.csv: $(EXPERIMENT)-sender-framelog.txt
	$(UTIL_DIR)/parse-tx-framelog.py $< > $@

$(EXPERIMENT)-receiver-framelog.csv: $(EXPERIMENT)-receiver-framelog.txt
	$(UTIL_DIR)/parse-rx-framelog.py $< > $@

clean:
	$(RM) $(EXPERIMENT)-summary.html 
	$(RM) $(EXPERIMENT)-summary.pdf
	$(RM) $(EXPERIMENT)-core-filter.pcap
	$(RM) $(EXPERIMENT)-sender.zpkt
	$(RM) $(EXPERIMENT)-core.zpkt
	$(RM) $(EXPERIMENT)-receiver.zpkt
	$(RM) $(EXPERIMENT)-sender-pkts.csv
	$(RM) $(EXPERIMENT)-join-pkts-up.csv
	$(RM) $(EXPERIMENT)-core-pkts.csv
	$(RM) $(EXPERIMENT)-receiver-pkts.csv
	$(RM) $(EXPERIMENT)-sender-frames.csv
	$(RM) $(EXPERIMENT)-core-frames.csv
	$(RM) $(EXPERIMENT)-core-flows.csv
	$(RM) $(EXPERIMENT)-receiver-frames.csv
	$(RM) $(EXPERIMENT)-sender-flows.csv
	$(RM) $(EXPERIMENT)-receiver-framelog.csv
	$(RM) $(EXPERIMENT)-sender-framelog.csv
	$(RM) $(EXPERIMENT)-pkts-join-up.csv

.PHONY: clean
