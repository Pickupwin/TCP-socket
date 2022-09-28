#include <core.p4>
#include <tna.p4>

header ethernet_h{
    bit<48> dst_addr;
    bit<48> src_addr;
    bit<16> ether_type;
}

struct ingress_headers_t{
    ethernet_h ethernet;
}

struct ingress_metadata_t{}

parser IngressParser(
    packet_in pkt,
    out ingress_headers_t hdr,
    out ingress_metadata_t md,
    out ingress_intrinsic_metadata_t ig_intr_md
){
    state start{
        pkt.extract(ig_intr_md);
        pkt.advance(PORT_METADATA_SIZE);
        transition parse_ethernet;
    }
    state parse_ethernet{
        pkt.extract(hdr.ethernet);
        transition accept;
    }
}

control Ingress(
    inout ingress_headers_t hdr,
    inout ingress_metadata_t metadata,
    in ingress_intrinsic_metadata_t ig_intr_md,
    in ingress_intrinsic_metadata_from_parser_t ig_prsr_md,
    inout ingress_intrinsic_metadata_for_deparser_t ig_dprsr_md,
    inout ingress_intrinsic_metadata_for_tm_t ig_tm_md
){
    action sendto(PortId_t port){
        ig_tm_md.ucast_egress_port=port;
        hdr.ethernet.src_addr=hdr.ethernet.src_addr^1;
    }
    action NoAction(){}
    action drop(){
        ig_dprsr_md.drop_ctl=1;
    }
    table eth_forward{
        key={
            hdr.ethernet.dst_addr:exact;
        }
        actions={
            sendto;
            NoAction;
        }
        size=16;    // capacity of entrys.
        default_action=NoAction();
    }

    apply{
        if(hdr.ethernet.isValid()){
            if(!eth_forward.apply().hit){
                if(ig_intr_md.ingress_port==188){
                    ig_tm_md.ucast_egress_port=184;
                }
                else if(ig_intr_md.ingress_port==184){
                    ig_tm_md.ucast_egress_port=188;
                }
                else{
                    drop();
                }
            }
        }else{
            drop();
        }
    }
}

control IngressDeparser(
    packet_out pkt,
    inout ingress_headers_t hdr,
    in ingress_metadata_t md,
    in ingress_intrinsic_metadata_for_deparser_t ig_dprsr_md
){
    apply{
        pkt.emit(hdr);
    }
}

struct egress_headers_t{}

struct egress_metadata_t{}

parser EgressParser(
    packet_in pkt,
    out egress_headers_t hdr,
    out egress_metadata_t md,
    out egress_intrinsic_metadata_t eg_intr_md
){
    state start{
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
    inout egress_intrinsic_metadata_for_output_port_t eg_op_md
){
    apply{
    }
}

control EgressDeparser(
    packet_out pkt,
    inout egress_headers_t hdr,
    in egress_metadata_t md,
    in egress_intrinsic_metadata_for_deparser_t eg_dprsr_md
){
    apply{
    }
}

Pipeline(
    IngressParser(),Ingress(),IngressDeparser(),
    EgressParser(),Egress(),EgressDeparser()
) pipe;

Switch(pipe) main;
