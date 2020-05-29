all:
	p4c --target tofino --arch tna -o output sdn-bier.p4 --p4runtime-files output/p4_runtime.p4info.txt
	sudo /opt/bf-sde-8.8.1/install/bin/bf_switchd --install-dir /opt/bf-sde-8.8.1/install --conf-file /opt/bf-sde-8.8.1/install/share/p4/targets/tofino/skip_p4.conf --skip-p4 --p4rt-server=0.0.0.0:9090

compile:
	git pull origin master
	p4c --target tofino --arch tna -o output sdn-bier.p4 --p4runtime-files output/p4_runtime.p4info.txt

start: 
	sudo /opt/bf-sde-8.9.1/install/bin/bf_switchd --install-dir /opt/bf-sde-8.9.1/install --conf-file /opt/bf-sde-8.9.1/install/share/p4/targets/tofino/skip_p4.conf --skip-p4 --p4rt-server=0.0.0.0:9091
