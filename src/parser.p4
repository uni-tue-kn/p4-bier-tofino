/*******************************************************************************
 * BAREFOOT NETWORKS CONFIDENTIAL & PROPRIETARY
 *
 * Copyright (c) 2018-2019 Barefoot Networks, Inc.
 * All Rights Reserved.
 *
 * NOTICE: All information contained herein is, and remains the property of
 * Barefoot Networks, Inc. and its suppliers, if any. The intellectual and
 * technical concepts contained herein are proprietary to Barefoot Networks,
 * Inc.
 * and its suppliers and may be covered by U.S. and Foreign Patents, patents in
 * process, and are protected by trade secret or copyright law.
 * Dissemination of this information or reproduction of this material is
 * strictly forbidden unless prior written permission is obtained from
 * Barefoot Networks, Inc.
 *
 * No warranty, explicit or implicit is provided, unless granted under a
 * written agreement with Barefoot Networks, Inc.
 *
 *
 ******************************************************************************/

parser TofinoIngressParser(
        packet_in pkt,
        out ingress_intrinsic_metadata_t ig_intr_md) {
    state start {
        pkt.extract(ig_intr_md);
        transition select(ig_intr_md.resubmit_flag) {
            1 : parse_resubmit;
            0 : parse_port_metadata;
        }
    }

    state parse_resubmit {
        // Parse resubmitted packet here.
        transition accept;
    }

    state parse_port_metadata {
#if __TARGET_TOFINO__ == 2
        pkt.advance(192);
#else
        pkt.advance(64);
#endif
        transition accept;
    }
}

parser TofinoEgressParser(
        packet_in pkt,
        out egress_intrinsic_metadata_t eg_intr_md) {

    state start {
        pkt.extract(eg_intr_md);
        transition accept;
    }
}


// ---------------------------------------------------------------------------
// Ingress parser
// ---------------------------------------------------------------------------
parser SwitchIngressParser(
        packet_in pkt,
        out header_t hdr,
        out ingress_metadata_t ig_md,
        out ingress_intrinsic_metadata_t ig_intr_md) {

    //Checksum<bit<16>>(HashAlgorithm_t.CSUM16) ipv4_checksum;
    TofinoIngressParser() tofino_parser;

    state start {
        tofino_parser.apply(pkt, ig_intr_md);
        transition select(ig_intr_md.ingress_port) {
            68: parse_port_down_header;
            196: parse_port_down_header;
            default: parse_ethernet;
        }
    }

    state parse_port_down_header {
        pkt.extract(hdr.port_down);
        transition parse_ethernet_2;
    }

    state parse_ethernet_2 {
        pkt.extract(hdr.ethernet);
        transition select(hdr.ethernet.ether_type) {
            ETHERTYPE_TOPOLOGY: parse_topology;
            default: accept;
        }
    }


    state parse_port_down_header_2 {
        pkt.extract(hdr.port_down);
        transition accept;
    }

    state parse_ethernet {
        pkt.extract(hdr.ethernet);
        transition select(hdr.ethernet.ether_type) {
            ETHERTYPE_IPV4      : parse_ipv4;
            ETHERTYPE_BIER      : parse_bier;
	        ETHERTYPE_PORT_DOWN : parse_port_down_header_2;
            TYPE_ARP	        : parse_arp;
            ETHERTYPE_TOPOLOGY  : parse_topology;
            default : accept;
        }
    }

    state parse_arp {
        pkt.extract(hdr.arp);
        transition accept;
    }

    state parse_ipv4 {
        pkt.extract(hdr.ipv4);
        transition select(hdr.ipv4.protocol) {
            TYPE_IP_IGMP: parse_igmp;
            TYPE_IP_BIER: parse_bier;
            default: accept;
        }
    }

    state parse_bier {
        pkt.extract(hdr.bier);
        transition select(hdr.bier.proto) {
            ETHERTYPE_IPV4: parse_ipv4_inner;
            default: accept;
        }
    }

    state parse_ipv4_inner {
        pkt.extract(hdr.ipv4_inner);
        transition accept;
    }

    state parse_topology {
        pkt.extract(hdr.topology);
        transition accept;
    }

    // parse igmp
    state parse_igmp {
        pkt.extract(hdr.igmp);
        transition accept;
    }


}

// ---------------------------------------------------------------------------
// Ingress Deparser
// ---------------------------------------------------------------------------
control SwitchIngressDeparser(
        packet_out pkt,
        inout header_t hdr,
        in ingress_metadata_t ig_md,
        in ingress_intrinsic_metadata_for_deparser_t ig_dprsr_md) {
    Mirror() mirror;

    apply {
        pkt.emit(hdr.ethernet);
        pkt.emit(hdr.arp);
        pkt.emit(hdr.topology);
        pkt.emit(hdr.port_down);
        pkt.emit(hdr.ipv4);
        pkt.emit(hdr.igmp);
        pkt.emit(hdr.bier);
        pkt.emit(hdr.ipv4_inner);

        if(ig_dprsr_md.mirror_type == 1) {
          mirror.emit<bier_md_t>(ig_md.mirror_session, hdr.bier_md);
        }
    }

}

// ---------------------------------------------------------------------------
// Egress parser
// ---------------------------------------------------------------------------
parser SwitchEgressParser(
        packet_in pkt,
        out header_t hdr,
        out egress_metadata_t eg_md,
        out egress_intrinsic_metadata_t eg_intr_md) {

    TofinoEgressParser() tofino_parser;

    state start {
        tofino_parser.apply(pkt, eg_intr_md);
        transition select(eg_intr_md.egress_port) {
            152: parse_bier_md;
            128: parse_bier_md;
            136: parse_bier_md;
            default : parse_ethernet;

        }
    }

    state parse_ethernet {
        pkt.extract(hdr.ethernet);
        transition select(hdr.ethernet.ether_type) {
            ETHERTYPE_IPV4 : parse_ipv4;
            ETHERTYPE_BIER : parse_bier;
	    ETHERTYPE_PORT_DOWN: parse_port_down_header;
            TYPE_ARP  	   : parse_arp;
            ETHERTYPE_TOPOLOGY: parse_topology;
            default : accept;
        }
    }

    state parse_port_down_header {
        pkt.extract(hdr.port_down);
        transition accept;
    }

    state parse_arp {
        pkt.extract(hdr.arp);
        transition accept;
    }

    state parse_ipv4 {
        pkt.extract(hdr.ipv4);
        transition select(hdr.ipv4.protocol) {
            TYPE_IP_IGMP: parse_igmp;
            TYPE_IP_BIER: parse_bier;
            default: accept;
        }
    }

    state parse_topology {
        pkt.extract(hdr.topology);
        transition accept;
    }


    state parse_bier {
        pkt.extract(hdr.bier);
        transition select(hdr.bier.proto) {
            ETHERTYPE_IPV4: parse_ipv4_inner;
            default: accept;
        }
    }

    state parse_bier_md {
          pkt.extract(hdr.bier_md);
          transition parse_ethernet;
    }

    state parse_ipv4_inner {
        pkt.extract(hdr.ipv4_inner);
        transition accept;
    }


    // parse igmp
    state parse_igmp {
        pkt.extract(hdr.igmp);
        transition accept;
    }
}

// ---------------------------------------------------------------------------
// Egress Deparser
// ---------------------------------------------------------------------------
control SwitchEgressDeparser(
        packet_out pkt,
        inout header_t hdr,
        in egress_metadata_t eg_md,
        in egress_intrinsic_metadata_for_deparser_t eg_dprsr_md) {
    Checksum<bit<16>>(HashAlgorithm_t.CSUM16) ipv4_checksum;
    apply {
        hdr.ipv4.hdr_checksum = ipv4_checksum.update(
                {hdr.ipv4.version,
                 hdr.ipv4.ihl,
                 hdr.ipv4.diffserv,
                 hdr.ipv4.total_len,
                 hdr.ipv4.identification,
                 hdr.ipv4.flags,
                 hdr.ipv4.frag_offset,
                 hdr.ipv4.ttl,
                 hdr.ipv4.protocol,
                 hdr.ipv4.src_addr,
                 hdr.ipv4.dst_addr});

        pkt.emit(hdr.ethernet);
	pkt.emit(hdr.arp);
        pkt.emit(hdr.topology);
        pkt.emit(hdr.port_down);
        pkt.emit(hdr.ipv4);
        pkt.emit(hdr.igmp);
        pkt.emit(hdr.bier);
        pkt.emit(hdr.ipv4_inner);
    }
}
