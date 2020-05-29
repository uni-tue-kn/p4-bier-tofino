control ARP(inout header_t hdr, in ingress_intrinsic_metadata_t ig_intr_md,
    inout ingress_intrinsic_metadata_for_tm_t ig_tm_md) {

    apply {
        hdr.arp.op = 2; // create arp response
        ipv4_addr_t tmp = hdr.arp.dst_ip_addr;
        hdr.arp.dst_ip_addr = hdr.arp.src_ip_addr;
        hdr.arp.src_ip_addr = tmp;
        ig_tm_md.ucast_egress_port = ig_intr_md.ingress_port;
    }
}
