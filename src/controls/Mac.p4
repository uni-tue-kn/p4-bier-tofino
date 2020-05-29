control Mac(inout header_t hdr, in egress_intrinsic_metadata_t eg_intr_md) {

    /*
     * Set layer 2 mac srcAddr and dstAddr
     */
    action set_mac(mac_addr_t srcAddr, mac_addr_t dstAddr) {
        hdr.ethernet.src_addr = srcAddr;
        hdr.ethernet.dst_addr = dstAddr;
    }

    /*
     * Helper table to trigger mac manipulation
     * matches on egress_port
     * table_add control.table_name control.adjust_mac <port> => <srcAddr> <dstAddr>
     * control name has to be adjusted based on the pipeline structure
     */
    table adjust_mac {
        key = {
            eg_intr_md.egress_port: exact;
        }
        actions = {
            set_mac;
        }
    }

    apply {
        adjust_mac.apply();

        if (hdr.ethernet.ether_type == TYPE_ARP) {
            hdr.arp.src_mac_addr = hdr.ethernet.src_addr;
            hdr.arp.dst_mac_addr = hdr.ethernet.dst_addr;
        }
    }
}
