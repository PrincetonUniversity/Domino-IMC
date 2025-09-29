A = ansible
AP = ansible-playbook
HOSTS_FILE = hosts.yml
SFU_HOST_SSH = aether.mgmt

install-mediasoup-demo:
	$(AP) -K -i $(HOSTS_FILE) $@.yml

start-mediasoup-demo:
	$(AP) -K -i $(HOSTS_FILE) $@.yml

stop-mediasoup-demo:
	$(AP) -K -i $(HOSTS_FILE) $@.yml

install-client:
	$(AP) -K -i $(HOSTS_FILE) $@.yml

configure-chrony:
	$(AP) -K -i $(HOSTS_FILE) $@.yml

ping:
	$(A) -i $(HOSTS_FILE) all -m ping

get-cert:
	scp $(SFU_HOST_SSH):~/opt/mediasoup/fullchain.pem files/

.PHONY: install-mediasoup-demo start-mediasoup-demo stop-mediasoup-demo install-client \
	configure-chrony ping get-cert
