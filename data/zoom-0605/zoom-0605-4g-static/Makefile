
EXPERIMENT = zoom-0605-4g-static
ZOOM_TOOLS = $(HOME)/src/research/zoom-analysis/build/release
UTIL_DIR   = ../../util

$(EXPERIMENT)-summary.html: summary.Rmd $(EXPERIMENT)-ue-pkts.csv $(EXPERIMENT)-core-pkts.csv \
	$(EXPERIMENT)-ue-frames.csv $(EXPERIMENT)-core-frames.csv $(EXPERIMENT)-ssim.csv \
	$(EXPERIMENT)-join-pkts-up.csv $(EXPERIMENT)-receiver-framelog.csv $(EXPERIMENT)-ue-framelog.csv
	Rscript -e 'rmarkdown::render("$<")'

$(EXPERIMENT)-summary.pdf: summary.Rmd $(EXPERIMENT)-ue-pkts.csv $(EXPERIMENT)-core-pkts.csv \
	$(EXPERIMENT)-ue-frames.csv $(EXPERIMENT)-core-frames.csv $(EXPERIMENT)-ssim.csv
	Rscript -e 'rmarkdown::render("$<")'

$(EXPERIMENT)-core-filter.pcap: $(EXPERIMENT)-core.pcap
	tshark -r $< -Y '((udp.dstport == 8801 && ip.ttl == 64) || (udp.srcport == 8801 && ip.ttl == 45)) && !gtp' -w $@

$(EXPERIMENT)-ue.zpkt: $(EXPERIMENT)-ue.pcap
	$(ZOOM_TOOLS)/zoom_flows -i $< -f $(EXPERIMENT)-core-flows.csv -z $@

$(EXPERIMENT)-core.zpkt: $(EXPERIMENT)-core-filter.pcap
	$(ZOOM_TOOLS)/zoom_flows -i $< -f $(EXPERIMENT)-core-flows.csv -z $@

$(EXPERIMENT)-ue-pkts.csv: $(EXPERIMENT)-ue.zpkt
	$(ZOOM_TOOLS)/zoom_rtp -i $< -p $@ -f $(EXPERIMENT)-ue-frames.csv

$(EXPERIMENT)-core-pkts.csv: $(EXPERIMENT)-core.zpkt
	$(ZOOM_TOOLS)/zoom_rtp -i $< -p $@ -f $(EXPERIMENT)-core-frames.csv

$(EXPERIMENT)-join-pkts-up.csv: join.Rmd $(EXPERIMENT)-ue-pkts.csv $(EXPERIMENT)-core-pkts.csv
	Rscript -e 'rmarkdown::render("$<")'
	
$(EXPERIMENT)-ue-framelog.csv: $(EXPERIMENT)-ue-framelog.txt
	$(UTIL_DIR)/parse-tx-framelog.py $< > $@

$(EXPERIMENT)-receiver-framelog.csv: $(EXPERIMENT)-receiver-framelog.txt
	$(UTIL_DIR)/parse-rx-framelog.py $< > $@

clean:
	$(RM) $(EXPERIMENT)-summary.html 
	$(RM) $(EXPERIMENT)-summary.pdf
	$(RM) $(EXPERIMENT)-core-filter.pcap
	$(RM) $(EXPERIMENT)-ue.zpkt
	$(RM) $(EXPERIMENT)-core.zpkt
	$(RM) $(EXPERIMENT)-ue-pkts.csv
	$(RM) $(EXPERIMENT)-join-pkts-up.csv
	$(RM) $(EXPERIMENT)-core-pkts.csv
	$(RM) $(EXPERIMENT)-ue-frames.csv
	$(RM) $(EXPERIMENT)-core-frames.csv
	$(RM) $(EXPERIMENT)-core-flows.csv
	$(RM) $(EXPERIMENT)-ue-flows.csv
	$(RM) $(EXPERIMENT)-receiver-framelog.csv
	$(RM) $(EXPERIMENT)-ue-framelog.csv
	$(RM) $(EXPERIMENT)-pkts-join-up.csv

.PHONY: clean
