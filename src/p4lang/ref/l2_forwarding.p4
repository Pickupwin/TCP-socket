#include<core.p4>
#include<tna.p4>

/*header definions*/

header ethernet_h {
    // bit<64> key;
    // bit<32> ignored;
    bit<48> dst;
    bit<48> src;
    bit<16> ether_type;
}

struct ingress_headers_t {
    ethernet_h	ethernet;
}
struct egress_headers_t {
    ethernet_h	ethernet;
}
struct ingress_metadata_t {
}
struct egress_metadata_t {
}

parser IngressParser(packet_in pkt,
        out ingress_headers_t hdr,
        out ingress_metadata_t metadata,
        out ingress_intrinsic_metadata_t ig_intr_md) {
    state start {
        pkt.extract(ig_intr_md);
        pkt.advance(PORT_METADATA_SIZE);
        transition parse_ethernet;
    }
    state parse_ethernet {
        pkt.extract(hdr.ethernet);
        transition select(hdr.ethernet.ether_type) {
            default: accept;
        }
    }
}

control Ingress(
        inout ingress_headers_t hdr,
        inout ingress_metadata_t metadata,
        in ingress_intrinsic_metadata_t ig_intr_md,
        in ingress_intrinsic_metadata_from_parser_t ig_prsr_md,
        inout ingress_intrinsic_metadata_for_deparser_t ig_dprsr_md,
        inout ingress_intrinsic_metadata_for_tm_t ig_tm_md) {
    
    action sendto(PortId_t port) {
        ig_tm_md.ucast_egress_port = port;
    }

    table eth_forward {
        key = { hdr.ethernet.dst : exact; }
        actions = { sendto; }
        size = 16;
    }

    apply {
        eth_forward.apply();
    }
}

control IngressDeparser(packet_out pkt,
        inout ingress_headers_t hdr,
        in ingress_metadata_t metadata,
        in ingress_intrinsic_metadata_for_deparser_t ig_dprsr_md) {
    apply{
        pkt.emit(hdr);
    }
}

parser EgressParser(packet_in pkt,
        out egress_headers_t hdr,
        out egress_metadata_t metadata,
        out egress_intrinsic_metadata_t eg_intr_md) {
    state start {
        pkt.extract(eg_intr_md);
        transition accept;
    }
}

control Egress(
        inout egress_headers_t hdr,
        inout egress_metadata_t metadata,
        in egress_intrinsic_metadata_t eg_intr_md,
        in egress_intrinsic_metadata_from_parser_t eg_prsr_md,
        inout egress_intrinsic_metadata_for_deparser_t eg_dprsr_md,
        inout egress_intrinsic_metadata_for_output_port_t eg_oport_md) {
    apply {

    }
}

control EgressDeparser(packet_out pkt,
        inout egress_headers_t hdr,
        in egress_metadata_t meta,
        in egress_intrinsic_metadata_for_deparser_t eg_dprsr_md) {
    apply{
        pkt.emit(hdr);
    }
}


    Pipeline
(IngressParser(),Ingress(),IngressDeparser(),
 EgressParser(),Egress(),EgressDeparser()
 )pipe;

    Switch(pipe) main;
