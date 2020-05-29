control BIER_FRR(inout header_t hdr, inout ingress_metadata_t ig_md, inout ingress_intrinsic_metadata_for_tm_t ig_tm_md, inout ingress_intrinsic_metadata_for_deparser_t ig_dprsr_md) {

    /*
    * Add ip header for FRR
    */
    action add_ip_header(ipv4_addr_t src_addr, ipv4_addr_t dst_addr) {
    	hdr.ipv4.setValid(); // set outer ipv4 header
    	hdr.ipv4.protocol = TYPE_IP_BIER; // set proto field to IP in IP tunnel (IP | Bier | IP)
    	hdr.ethernet.ether_type = ETHERTYPE_IPV4;
    	hdr.ipv4.src_addr = src_addr;  // set src and dst Adress
    	hdr.ipv4.dst_addr = dst_addr;  // for ip tunnel
    }

    action clone_and_forward(bierBitmask fbm, PortId_t e_port) {
        hdr.bier.bs = hdr.bier.bs & fbm; // new bier bs for outgoing packet
        ig_tm_md.ucast_egress_port = e_port;
    }

    /*
    * Tunnel bier packet to NH
    */
    action forward_encap(bierBitmask fbm, ipv4_addr_t src_addr, ipv4_addr_t dst_addr) {
        add_ip_header(src_addr, dst_addr); // add ip header for tunnel
        clone_and_forward(fbm, RECIRCULATE_PORT); // adjust bier packet, recirculate
    }


    table bift {
        key = {
            hdr.bier.bs: ternary;
            ig_tm_md.ucast_egress_port: exact;
        }
        actions = {
            forward_encap;
        }
    }

    apply {
	       bift.apply();
    }
}
