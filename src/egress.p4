#include "controls/Mac.p4"


control egress(
    inout header_t hdr,
    inout egress_metadata_t eg_md, in egress_intrinsic_metadata_t eg_intr_md, in egress_intrinsic_metadata_from_parser_t eg_intr_from_prsr,
    inout egress_intrinsic_metadata_for_deparser_t eg_intr_md_for_dprsr,
    inout egress_intrinsic_metadata_for_output_port_t eg_intr_md_for_oport) {

    Mac() mac_c;

    apply {
        // Remove metadata header, adjust bier header
        if (hdr.bier_md.isValid()) {
            hdr.bier.bs = hdr.bier_md.bs;
            hdr.bier_md.setInvalid();
            hdr.ipv4.setInvalid(); // remove outer ip header from possible bier-frr
            hdr.ethernet.ether_type = ETHERTYPE_BIER;
        }

        mac_c.apply(hdr, eg_intr_md);
    }
}
