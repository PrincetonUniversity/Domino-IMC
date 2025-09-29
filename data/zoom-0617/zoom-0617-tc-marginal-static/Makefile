
EXPERIMENT = zoom-0617-tc-marginal-static
ZOOM_TOOLS = $(HOME)/src/research/zoom-analysis/build/release
UTIL_DIR   = ../../util

$(EXPERIMENT)-summary.html: summary.Rmd $(EXPERIMENT)-sender-pkts.csv $(EXPERIMENT)-receiver-pkts.csv \
	$(EXPERIMENT)-sender-frames.csv $(EXPERIMENT)-receiver-frames.csv $(EXPERIMENT)-ssim.csv \
	$(EXPERIMENT)-join-pkts-up.csv $(EXPERIMENT)-receiver-framelog.csv $(EXPERIMENT)-sender-framelog.csv
	Rscript -e 'rmarkdown::render("$<")'

$(EXPERIMENT)-summary.pdf: summary.Rmd $(EXPERIMENT)-sender-pkts.csv $(EXPERIMENT)-receiver-pkts.csv \
	$(EXPERIMENT)-sender-frames.csv $(EXPERIMENT)-receiver-frames.csv $(EXPERIMENT)-ssim.csv
	Rscript -e 'rmarkdown::render("$<")'

$(EXPERIMENT)-sender.zpkt: $(EXPERIMENT)-sender.pcap
	$(ZOOM_TOOLS)/zoom_flows -i $< -f $(EXPERIMENT)-receiver-flows.csv -z $@

$(EXPERIMENT)-receiver.zpkt: $(EXPERIMENT)-receiver.pcap
	$(ZOOM_TOOLS)/zoom_flows -i $< -f $(EXPERIMENT)-receiver-flows.csv -z $@

$(EXPERIMENT)-sender-pkts.csv: $(EXPERIMENT)-sender.zpkt
	$(ZOOM_TOOLS)/zoom_rtp -i $< -p $@ -f $(EXPERIMENT)-sender-frames.csv

$(EXPERIMENT)-receiver-pkts.csv: $(EXPERIMENT)-receiver.zpkt
	$(ZOOM_TOOLS)/zoom_rtp -i $< -p $@ -f $(EXPERIMENT)-receiver-frames.csv

$(EXPERIMENT)-join-pkts-up.csv: join.Rmd $(EXPERIMENT)-sender-pkts.csv $(EXPERIMENT)-receiver-pkts.csv
	Rscript -e 'rmarkdown::render("$<")'
	
$(EXPERIMENT)-sender-framelog.csv: $(EXPERIMENT)-sender-framelog.txt
	$(UTIL_DIR)/parse-tx-framelog.py $< > $@

$(EXPERIMENT)-receiver-framelog.csv: $(EXPERIMENT)-receiver-framelog.txt
	$(UTIL_DIR)/parse-rx-framelog.py $< > $@

clean:
	$(RM) $(EXPERIMENT)-summary.html 
	$(RM) $(EXPERIMENT)-summary.pdf
	$(RM) $(EXPERIMENT)-sender.zpkt
	$(RM) $(EXPERIMENT)-receiver.zpkt
	$(RM) $(EXPERIMENT)-sender-pkts.csv
	$(RM) $(EXPERIMENT)-join-pkts-up.csv
	$(RM) $(EXPERIMENT)-receiver-pkts.csv
	$(RM) $(EXPERIMENT)-sender-frames.csv
	$(RM) $(EXPERIMENT)-receiver-frames.csv
	$(RM) $(EXPERIMENT)-receiver-flows.csv
	$(RM) $(EXPERIMENT)-sender-flows.csv
	$(RM) $(EXPERIMENT)-receiver-framelog.csv
	$(RM) $(EXPERIMENT)-sender-framelog.csv
	$(RM) $(EXPERIMENT)-pkts-join-up.csv

.PHONY: clean
