control BIER(inout header_t hdr, inout ingress_metadata_t ig_md, inout ingress_intrinsic_metadata_for_tm_t ig_tm_md, inout ingress_intrinsic_metadata_for_deparser_t ig_dprsr_md) {

    action clone() {
    }

    action clone_and_forward(bierBitmask fbm, PortId_t e_port) {
        // save new bier bs for clone
        hdr.bier_md.setValid();
        hdr.bier_md.bs = hdr.bier.bs;
        hdr.bier.bs = hdr.bier.bs & fbm; // new bier bs for outgoing packet
        ig_tm_md.ucast_egress_port = e_port;
    }

    action decap() {
        hdr.ethernet.ether_type = hdr.bier.proto;
        hdr.bier.setInvalid(); // remove bier header

        hdr.ipv4.setValid();
        hdr.ipv4 = hdr.ipv4_inner; // copy original ipv4 header to outer header
        hdr.ipv4_inner.setInvalid();

        ig_tm_md.ucast_egress_port = DECAP_PORT; // recirculate
    }

    table bift {
        key = {
            hdr.bier.bs: ternary;
        }
        actions = {
            clone_and_forward;
            decap;
        }
    }

    apply {
        if (bift.apply().hit) {
            clone();
        }
    }
}
