all: compile start
	@echo "done"

start:
	./controller.py --loglevel 3 --grpc-port 9091 --device-id 0 --bfr-id 1 --logfile logs.txt --prog-name sdn-bier --bin-path ../output/pipe/tofino.bin --cxt-path ../output/pipe/context.json --p4info ../output/p4_runtime.p4info.txt --bmv2-json ../output/sdn-bier.conf --listen-port 9095 --ports tofino-ports.json

compile:
	cd ../ && make compile
		
