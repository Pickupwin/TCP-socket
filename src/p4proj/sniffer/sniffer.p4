#include <core.p4>
#include <tna.p4>

const bit<48> MIRROR_TARGET_MAC = 0x08c0eb333174;

header ethernet_h{
    bit<48> dst_addr;
    bit<48> src_addr;
    bit<16> ether_type;
}

struct ingress_headers_t{
    ethernet_h ethernet;
}

struct ingress_metadata_t{
    MirrorId_t mirror_session;
    bit<8> mir_hdr_type;
}

parser IngressParser(
    packet_in pkt,
    out ingress_headers_t hdr,
    out ingress_metadata_t md,
    out ingress_intrinsic_metadata_t ig_intr_md
){
    state start{
        transition init_meta;
    }
    state init_meta{
        md.mirror_session=0;
        md.mir_hdr_type=0;
        transition parse_start;
    }
    state parse_start{
        pkt.extract(ig_intr_md);
        pkt.advance(PORT_METADATA_SIZE);
        transition parse_ethernet;
    }
    state parse_ethernet{
        pkt.extract(hdr.ethernet);
        transition accept;
    }
}

const bit<3> ING_MIRROR = 7;
const bit<8> MIRROR_HEADER_TYPE = 0xA2;

header mirror_h{
    bit<8> header_type;
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
    }
    action drop(){
        ig_dprsr_md.drop_ctl=1;
    }
    table eth_forward{
        key={
            hdr.ethernet.dst_addr:exact;
        }
        actions={
            sendto;
        }
        size=16;    // capacity of entrys.
    }
    action ing_mirror(MirrorId_t mirs){
        ig_dprsr_md.mirror_type=ING_MIRROR;
        metadata.mirror_session=mirs;
        metadata.mir_hdr_type=MIRROR_HEADER_TYPE;
    }
    table ing_mirror_table{
        key={
            ig_intr_md.ingress_port:exact;
        }
        actions={
            ing_mirror;
        }
        size=16;
    }
    apply{
        switch(eth_forward.apply().action_run){
            sendto:{}
            default:{
                ing_mirror_table.apply();
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
        }
    }
}

control IngressDeparser(
    packet_out pkt,
    inout ingress_headers_t hdr,
    in ingress_metadata_t md,
    in ingress_intrinsic_metadata_for_deparser_t ig_dprsr_md
){
    Mirror() ing_mirror;
    apply{
        if(ig_dprsr_md.mirror_type==ING_MIRROR){
            ing_mirror.emit<mirror_h>(
                md.mirror_session,
                {
                    md.mir_hdr_type
                }
            );
        }
        pkt.emit(hdr);
    }
}

struct egress_headers_t{
    ethernet_h eth_hdr;
}

struct egress_metadata_t{
    bit<1> is_mirror;
}

parser EgressParser(
    packet_in pkt,
    out egress_headers_t hdr,
    out egress_metadata_t md,
    out egress_intrinsic_metadata_t eg_intr_md
){
    mirror_h tmp_mir_hdr;
    state start{
        transition init_meta;
    }
    state init_meta{
        md.is_mirror=0;
        transition parse_start;
    }
    state parse_start{
        pkt.extract(eg_intr_md);
        tmp_mir_hdr=pkt.lookahead<mirror_h>();
        transition select(tmp_mir_hdr.header_type){
            MIRROR_HEADER_TYPE:
                parse_mirror;
            default:
                parse_ethernet;
        }
    }
    state parse_mirror{
        pkt.extract(tmp_mir_hdr);
        md.is_mirror=1;
        transition parse_ethernet;
    }
    state parse_ethernet{
        pkt.extract(hdr.eth_hdr);
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
        if(metadata.is_mirror==1){
            hdr.eth_hdr.src_addr=hdr.eth_hdr.dst_addr;
            hdr.eth_hdr.dst_addr=MIRROR_TARGET_MAC;
        }
    }
}

control EgressDeparser(
    packet_out pkt,
    inout egress_headers_t hdr,
    in egress_metadata_t md,
    in egress_intrinsic_metadata_for_deparser_t eg_dprsr_md
){
    apply{
        pkt.emit(hdr);
    }
}

Pipeline(
    IngressParser(),Ingress(),IngressDeparser(),
    EgressParser(),Egress(),EgressDeparser()
) pipe;

Switch(pipe) main;
