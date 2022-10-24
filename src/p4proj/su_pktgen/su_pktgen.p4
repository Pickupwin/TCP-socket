#include <core.p4>
#include <tna.p4>

const bit<3> PKTGEN_APP_ID = 1;

struct pktgen_base_header_t{
    bit<3> _pad1;
    bit<2> pipe_id;
    bit<3> app_id;
}

struct ingress_headers_t{}

struct ingress_metadata_t{
    bit<1> is_timer;
    pktgen_timer_header_t timer;
}

parser IngressParser(
    packet_in pkt,
    out ingress_headers_t hdrs,
    out ingress_metadata_t md,
    out ingress_intrinsic_metadata_t ig_intr_md
){
    state start{
        pkt.extract(ig_intr_md);
        pkt.advance(PORT_METADATA_SIZE);
        transition init_meta;
    }
    state init_meta{
        md.is_timer=0;
        pktgen_base_header_t pktgen_base_hdr=pkt.lookahead<pktgen_base_header_t>();
        transition select(pktgen_base_hdr.app_id){
            PKTGEN_APP_ID: parse_pktgen_timer;
            default: accept;
        }
    }
    state parse_pktgen_timer{
        pkt.extract(md.timer);
        md.is_timer=1;
        transition accept;
    }
}

control Ingress(
    inout ingress_headers_t hdrs,
    inout ingress_metadata_t md,
    in ingress_intrinsic_metadata_t ig_intr_md,
    in ingress_intrinsic_metadata_from_parser_t ig_prsr_md,
    inout ingress_intrinsic_metadata_for_deparser_t ig_dprsr_md,
    inout ingress_intrinsic_metadata_for_tm_t ig_tm_md
){

    DirectRegister<bit<8>>(0) timer_cnt;
    DirectRegisterAction<bit<8>,bit<8>>(timer_cnt) timer_cnt_incr={
        void apply(inout bit<8> data, out bit<8> ret){
            data=data+1;
            ret=data;
        }
    };
    apply{
        
        if(ig_intr_md.ingress_port==184){
            ig_tm_md.ucast_egress_port=188;
        }
        if(ig_intr_md.ingress_port==188){
            ig_tm_md.ucast_egress_port=184;
        }

        if(md.is_timer==1){
            timer_cnt_incr.execute();
            ig_tm_md.ucast_egress_port=184;
        }
    }
}



control IngressDeparser(
    packet_out pkt,
    inout ingress_headers_t hdrs,
    in ingress_metadata_t md,
    in ingress_intrinsic_metadata_for_deparser_t ig_dprsr_md
){
    apply{
        pkt.emit(hdrs);
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
