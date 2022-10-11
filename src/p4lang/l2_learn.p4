#include <core.p4>
#include <tna.p4>

typedef bit<48> macAddr_t;

const ReplicationId_t L2_MCAST_RID = 0xFFFF;
const bit<32> MAC_TABLE_SIZE=65536;

const bit<3> L2_LEARN_DIGEST=1;

header ethernet_h{
    macAddr_t dst_addr;
    macAddr_t src_addr;
    bit<16> ether_type;
}

struct ingress_headers_t{
    ethernet_h eth_hdr;
}

struct port_metadata_t{
    bit<3> port_pcp;
    bit<12> port_vid;
    bit<9> l2_xid;
}

struct ingress_metadata_t{
    port_metadata_t port_properties;
    PortId_t port_move;
    PortId_t ingress_port;
    bit<1> smac_hit;
}

parser IngressParser(
    packet_in pkt,
    out ingress_headers_t hdr,
    out ingress_metadata_t md,
    out ingress_intrinsic_metadata_t ig_intr_md
){
    state start{
        pkt.extract(ig_intr_md);
        md.port_properties=port_metadata_unpack<port_metadata_t>(pkt);
        transition init_meta;
    }
    state init_meta{
        md.ingress_port=ig_intr_md.ingress_port;
        transition parse_ethernet;
    }
    state parse_ethernet{
        pkt.extract(hdr.eth_hdr);
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
    action dmac_unicast(PortId_t port){
        ig_tm_md.ucast_egress_port=port;
    }
    action dmac_multicast(MulticastGroupId_t mcast_grp){
        ig_tm_md.mcast_grp_a=mcast_grp;
        ig_tm_md.rid=L2_MCAST_RID;
        ig_tm_md.level2_exclusion_id=md.port_properties.l2_xid;
    }
    action dmac_drop(){
        ig_dprsr_md.drop_ctl=1;
        exit;
    }
    action dmac_miss(){
        dmac_multicast((MulticastGroupId_t)0);
    }
    table dst_mac{
        key={
            hdr.eth_hdr.dst_addr:exact;
        }
        actions={
            dmac_unicast;dmac_multicast;dmac_miss;dmac_drop;
        }
        size=MAC_TABLE_SIZE;
        default_action=dmac_miss();
    }
    action smac_hit(PortId_t port){
        md.port_move=ig_intr_md.ingress_port^port;
        md.smac_hit=1;
    }
    action smac_miss(){}
    action smac_drop(){
        ig_dprsr_md.drop_ctl=1;
        exit;
    }
    @idletime_precision(3)
    table src_mac{
        key={
            hdr.eth_hdr.src_addr:exact;
        }
        actions={
            smac_hit;smac_miss;smac_drop;
        }
        size=MAC_TABLE_SIZE;
        default_action=smac_miss();
        idle_timeout=true;
    }
    apply{
        src_mac.apply();
        if(md.smac_hit==0 || md.port_move!=0){
            ig_dprsr_md.digest_type=L2_LEARN_DIGEST;
        }
        dst_mac.apply();
    }
}

struct l2_digest_t{
    bit<48> src_mac;
    PortId_t in_port;
    PortId_t port_move;
    bit<1> smac_hit;
}

control IngressDeparser(
    packet_out pkt,
    inout ingress_headers_t hdr,
    in ingress_metadata_t md,
    in ingress_intrinsic_metadata_for_deparser_t ig_dprsr_md
){
    Digest<l2_digest_t>() l2_digest;

    apply{
        if(ig_dprsr_md.digest_type==L2_LEARN_DIGEST){
            l2_digest.pack({
                hdr.eth_hdr.src_addr,
                md.ingress_port,
                md.port_move, md.smac_hit
            });
        }
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