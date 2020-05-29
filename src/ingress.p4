#include "controls/IP.p4"

#include "controls/IP_FRR.p4"

#include "controls/ARP.p4"

#include "controls/Topology.p4"

#include "controls/BIER.p4"

#include "controls/BIER_FRR.p4"

#include "controls/Port.p4"

#include "controls/Port_Down.p4"

control ingress(
    inout header_t hdr,
    inout ingress_metadata_t ig_md, in ingress_intrinsic_metadata_t ig_intr_md, in ingress_intrinsic_metadata_from_parser_t ig_prsr_md,
    inout ingress_intrinsic_metadata_for_deparser_t ig_dprsr_md,
    inout ingress_intrinsic_metadata_for_tm_t ig_tm_md) {

    IP() ip_c;
    IP_FRR() ip_frr_c;
    ARP() arp_c;
    Topology() topology_c;
    BIER() bier_c;
    BIER_FRR() bier_frr_c;
    Port() port_c;
    Port_Down() port_down_c;

    // used for recirc round robin
    Register < bit < 8 > , bit < 1 >> (128) mirror_port;
    RegisterAction < bit < 8 > , bit < 1 > , bit < 8 >> (mirror_port) mirror_session = {
        void apply(inout bit < 8 > value, out bit < 8 > read_value) {
            read_value = value;

            if (value >= (RECIRC_PORTS - 1)) {
                value = 0;
            } else {
                value = value + 1;
            }
        }
    };

    // used for port down measurement
    Register<bit<1>, bit<1>>(1, 0) down_p;
    RegisterAction<bit<1>, bit<1>, bit<1>>(down_p) down = {
        void apply(inout bit<1> value, out bit<1> read_value) {
            value = 1;
            read_value = 1;
        }
    };

    RegisterAction<bit<1>, bit<1>, bit<1>>(down_p) read_down = {
        void apply(inout bit<1> value, out bit<1> read_value) {
            read_value = value;
            value = value;
        }
    };

    action nop() {}

    table reset_clone {
	key = {
		hdr.bier_md.bs: exact;
	}
	actions = {
		nop;
	}
    }


    apply {

        ig_md.port_event = 2; // read port

        if (hdr.ethernet.ether_type == ETHERTYPE_TOPOLOGY) {
            topology_c.apply(hdr, ig_md, ig_intr_md, ig_tm_md);
            ig_md.port_event = 1; // port up event
        }
        else if (hdr.ethernet.ether_type == ETHERTYPE_IPV4) {
            ip_c.apply(hdr, ig_md, ig_tm_md, ig_intr_md);
        }
        else if (hdr.ethernet.ether_type == TYPE_ARP) {
            arp_c.apply(hdr, ig_intr_md, ig_tm_md);
        }
        else if (hdr.ethernet.ether_type == ETHERTYPE_BIER) {
            bier_c.apply(hdr, ig_md, ig_tm_md, ig_dprsr_md);
            bit<1> d = read_down.execute(0);

            if(d == 1) {
                hdr.ipv4_inner.protocol = 6;
            } 
        }
        else if (hdr.ethernet.ether_type == ETHERTYPE_PORT_DOWN) { // send port down packets to controller
            port_down_c.apply(hdr, ig_intr_md, ig_md, ig_tm_md, ig_dprsr_md);
            down.execute(0);
        }

        port_c.apply(hdr, ig_intr_md, ig_md, ig_tm_md, ig_dprsr_md);

        if (ig_tm_md.ucast_egress_port > 0 && ig_tm_md.ucast_egress_port != RECIRCULATE_PORT) {
            if (ig_md.port_status == 0 && hdr.ethernet.ether_type == ETHERTYPE_BIER) { // selected egress is down
                bier_frr_c.apply(hdr, ig_md, ig_tm_md, ig_dprsr_md); // apply bier frr
            } 
            else if (ig_md.port_status == 0 && hdr.ethernet.ether_type == ETHERTYPE_IPV4) {
                ip_frr_c.apply(hdr, ig_md, ig_tm_md, ig_intr_md);
            }
        }

        //// update bier_md header
        if (hdr.bier.isValid() && hdr.bier_md.isValid()) {
            hdr.bier_md.bs = hdr.bier_md.bs & ~hdr.bier.bs;
	
	    if(!reset_clone.apply().hit) {
                ig_dprsr_md.mirror_type = 1;
	    }
        }

        if (ig_dprsr_md.mirror_type == 1) {
            ig_md.mirror_session = (bit < 10 > ) mirror_session.execute(0);
            ig_md.mirror_session = ig_md.mirror_session + 1000;
        }
    }
}
