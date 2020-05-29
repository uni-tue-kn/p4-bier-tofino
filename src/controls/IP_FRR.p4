control IP_FRR(inout header_t hdr, in ingress_metadata_t ig_md, inout ingress_intrinsic_metadata_for_tm_t ig_tm_md, in ingress_intrinsic_metadata_t ig_intr_md) {

    action forward(PortId_t e_port) {
        ig_tm_md.ucast_egress_port = e_port;
    }

    table ip_forward {
        key = {
            hdr.ipv4.dst_addr: exact;
            ig_tm_md.ucast_egress_port: exact;
        }
        actions = {
            forward;
        }
    }

    apply {
        ip_forward.apply();
    }
}
