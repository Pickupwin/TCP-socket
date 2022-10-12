#include <core.p4>
#include <tna.p4>

header ethernet_h{
    bit<48> dst_addr;
    bit<48> src_addr;
    bit<16> ether_type;
}

header ipv4_h{
    bit<4> version;
    bit<4> hdr_len;
    bit<8> diff_serv;
    bit<16> tot_len;
    bit<16> identify;
    bit<3> flags;
    bit<13> frag_off;
    bit<8> ttl;
    bit<8> protocol;
    bit<16> checksum;
    bit<32> src_addr;
    bit<32> dst_addr;
}

header udp_h{
    bit<16> src_port;
    bit<16> dst_port;
    bit<16> pkt_len;
    bit<16> checksum;
}

header BTH_h{
    bit<8> op_code;
    bit<24> murmur24;
    bit<8> reserve8;
    bit<24> dst_qp;
    bit<1> ack_req;
    bit<7> reserve7;
    bit<24> psn;
}

struct ingress_headers_t{
    ethernet_h eth_hdr;
    ipv4_h ipv4_hdr;
    udp_h udp_hdr;
    BTH_h bth_hdr;
}

struct ingress_metadata_t{
    bit<1> is_rdma;
}

parser IngressParser(
    packet_in pkt,
    out ingress_headers_t hdrs,
    out ingress_metadata_t md,
    out ingress_intrinsic_metadata_t ig_intr_md
){
    state start{
        transition init_meta;
    }
    state init_meta{
        md.is_rdma=0;
        transition parse_start;
    }
    state parse_start{
        pkt.extract(ig_intr_md);
        pkt.advance(PORT_METADATA_SIZE);
        transition parse_ethernet;
    }
    state parse_ethernet{
        pkt.extract(hdrs.eth_hdr);
        transition select(hdrs.eth_hdr.ether_type){
            0x0800: parse_ipv4;
            default: other_accept;
        }
    }
    state parse_ipv4{
        pkt.extract(hdrs.ipv4_hdr);
        transition select(hdrs.ipv4_hdr.protocol){
            0x11: parse_udp;
            default: other_accept;
        }
    }
    state parse_udp{
        pkt.extract(hdrs.udp_hdr);
        transition select(hdrs.udp_hdr.dst_port){
            4791: parse_rroce;
            default: other_accept;
        }
    }
    state parse_rroce{
        pkt.extract(hdrs.bth_hdr);
        md.is_rdma=1;
        transition accept;
    }
    state other_accept{
        transition accept;
    }
}

control Ingress(
    inout ingress_headers_t hdr,
    inout ingress_metadata_t md,
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
            hdr.eth_hdr.dst_addr:exact;
        }
        actions={
            sendto;
        }
        size=16;    // capacity of entries;
    }
    #define RDMA_MOD 20
    DirectRegister<bit<8>>(1) rdma_mod;
    DirectRegisterAction<bit<8>,bit<1>>(rdma_mod) rdma_mod_incr={
        void apply(inout bit<8> data, out bit<1> ret){
            if(data>=RDMA_MOD){
                ret=1;
                data=1;
            }
            else{
                ret=0;
                data=data+1;
            }
        }
    };
    apply{
        if(md.is_rdma==1){  //rocev2
            if(rdma_mod_incr.execute()==1){
                drop();
            }
        }
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
        transition init_meta;
    }
    state init_meta{
        transition parse_start;
    }
    state parse_start{
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
        pkt.emit(hdr);
    }
}

Pipeline(
    IngressParser(),Ingress(),IngressDeparser(),
    EgressParser(),Egress(),EgressDeparser()
) pipe;

Switch(pipe) main;
