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
    bit<48> tstamp;
    MirrorId_t mir_sess;
    bit<8> mir_hdr_type;
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
        md.tstamp=0;
        md.mir_hdr_type=0;
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

const bit<3> ING_MIRROR = 7;
const bit<8> MIRROR_HEADER_TYPE = 0xA2;

header ing_mirror_h{
    bit<8> header_type;
    bit<48> tstamp;
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
    // DirectCounter<bit<24>>(CounterType_t.PACKETS) rdma_counter;
    #define RDMA_MOD 20
    DirectRegister<bit<8>>(1) rdma_mod;
    DirectRegisterAction<bit<8>,bit<1>>(rdma_mod) rdma_mod_incr = {
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
    action ing_mirror(MirrorId_t mirror_session){
        ig_dprsr_md.mirror_type=ING_MIRROR;
        md.mir_sess=mirror_session;
        md.mir_hdr_type=MIRROR_HEADER_TYPE;
        md.tstamp=ig_prsr_md.global_tstamp;
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
        if(md.is_rdma==1){
            if(rdma_mod_incr.execute()==1){
                drop();
            }
        }
        else{
            ing_mirror_table.apply();
        }
        if(hdr.eth_hdr.isValid()){
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
    Mirror() ing_mirror;
    apply{
        if(ig_dprsr_md.mirror_type==ING_MIRROR){
            ing_mirror.emit<ing_mirror_h>(
                md.mir_sess,
                {
                    md.mir_hdr_type,
                    md.tstamp
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
    bit<48> tstamp;
}

parser EgressParser(
    packet_in pkt,
    out egress_headers_t hdr,
    out egress_metadata_t md,
    out egress_intrinsic_metadata_t eg_intr_md
){
    ing_mirror_h tmp_mir_hdr;
    state start{
        transition init_meta;
    }
    state init_meta{
        md.is_mirror=0;
        md.tstamp=0;
        transition parse_start;
    }
    state parse_start{
        pkt.extract(eg_intr_md);
        tmp_mir_hdr=pkt.lookahead<ing_mirror_h>();
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
        md.tstamp=tmp_mir_hdr.tstamp;
        transition parse_ethernet;
    }
    state parse_ethernet{
        pkt.extract(hdr.eth_hdr);
        transition accept;
    }
}

const bit<48> MIRROR_TARGET_MAC = 0x08c0eb333174;

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
            hdr.eth_hdr.src_addr=metadata.tstamp;
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
