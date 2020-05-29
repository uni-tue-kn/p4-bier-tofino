control Topology(inout header_t hdr,
    inout ingress_metadata_t ig_md, in ingress_intrinsic_metadata_t ig_intr_md,
    inout ingress_intrinsic_metadata_for_tm_t ig_tm_md) {

    apply {
        if (ig_intr_md.ingress_port == 68 || ig_intr_md.ingress_port == 196) {
            ig_tm_md.mcast_grp_a = 1; // flood group
        }
	else {
            if (ig_intr_md.ingress_port == RECIRCULATE_PORT || ig_intr_md.ingress_port == DECAP_PORT) {
                ig_tm_md.ucast_egress_port = CPU_PORT;
            }
    	else {
            if(ig_intr_md.ingress_port != 8) {
                hdr.topology.port = (bit < 16 > ) ig_intr_md.ingress_port;
            }
            else {
 		hdr.topology.port = 56;
            }

                if (ig_intr_md.ingress_port < 128) {
                    ig_tm_md.ucast_egress_port = RECIRCULATE_PORT;
                }
				else {
                    ig_tm_md.ucast_egress_port = DECAP_PORT;
                }
            }
        }
    }
}
