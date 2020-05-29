control IP(inout header_t hdr, inout ingress_metadata_t ig_md, inout ingress_intrinsic_metadata_for_tm_t ig_tm_md, in ingress_intrinsic_metadata_t ig_intr_md) {

    action decap() {
	hdr.ethernet.ether_type = ETHERTYPE_BIER;
        hdr.ipv4.setInvalid();
	ig_tm_md.ucast_egress_port = RECIRCULATE_PORT;
    }

    action forward(PortId_t e_port) {
        ig_tm_md.ucast_egress_port = e_port;
    }

    table ip_forward {
        key = {
            hdr.ipv4.dst_addr: lpm;
        }
        actions = {
            forward;
	    decap;
        }
    }

    action add_bier(bierBitmask bs) {
        hdr.bier.setValid(); // activate bier header
        hdr.bier.proto = hdr.ethernet.ether_type;
        hdr.bier.bs = bs;

        hdr.ethernet.ether_type = ETHERTYPE_BIER;

        ig_tm_md.ucast_egress_port = RECIRCULATE_PORT; // recirculate

        // copy outer ip header to inner, remove outer
        hdr.ipv4_inner.setValid();
        hdr.ipv4_inner = hdr.ipv4;
        hdr.ipv4.setInvalid();
    }

    table encap_ipv4 {
        key = {
            hdr.ipv4.dst_addr: exact;
        }
        actions = {
            add_bier;
        }
    }

    // used for native mc for directly attached hosts
    action native_mc(bit<16> mgrp_id) {
        ig_tm_md.mcast_grp_a = mgrp_id;
    }

    table ipv4_mc {
        key = {
            hdr.ipv4.dst_addr: exact;
        }
        actions = {
            native_mc;
        }
    }

    apply {
        if (hdr.igmp.isValid()) {
            ig_tm_md.ucast_egress_port = CPU_PORT; // send igmp packet to controller
        }
        else if (!ip_forward.apply().hit) {
            if (ig_intr_md.ingress_port != DECAP_PORT) {
                if(!encap_ipv4.apply().hit) {
			ipv4_mc.apply();
		}
            }
            else {
                ipv4_mc.apply();
            }
        }
    }
}
