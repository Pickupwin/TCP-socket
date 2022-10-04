#include<core.p4>
#include<tna.p4>
#include <headers.p4>

const bit<32> DATATYPE_VALUE = 32w0x1;
const bit<32> DATATYPE_BUCKET = 32w0x2;
// resp: resp_metadata + oneof(resp_bucket, resp_value)
header resp_metadata_h {
    bit<32> type;
    bit<32> len;
}
header resp_bucket_h {
    bit<64> key;
    bit<64> addr;
}
header resp_value {
    // variable length, currently ignored
}

struct ingress_headers_t {
    ethernet_h	ethernet;
    ipv4_h	ipv4;
    udp_h	udp;
    GRH_h	grh;
    BTH_h	bth;
    AETH_h	aeth;
    RETH_h	reth;
    CRC_h	crc;
    resp_metadata_h resp_metadata;
    resp_bucket_h resp_bucket;
}

enum dest_table_t {
    TABLE_MAIN,
    TABLE_SECONDARY,
    TABLE_OVERFLOW
}

struct ingress_metadata_t {
    rdma_type_t rdma_type;
    roce_version_t roce_version;
    bit<64> key;
    bit<64> secondary_overflow_address;
    bit<64> bucket;
    bit<64> bucket2;
    bit<64> bucket_to_probe;
    bit<64> offset;
    // dest_table_t dest_table;
    bit<2> dest_table;  /** 0 for main, 1 for secondary, 2 for overflow. */
    bit<1> cache_hit;
}

struct egress_metadata_t {
    rdma_type_t rdma_type;
    roce_version_t roce_version;
}

struct egress_headers_t {
    ethernet_h	ethernet;
    ipv4_h ipv4;
    udp_h udp;
    GRH_h	grh;
    BTH_h	bth;
    RETH_h	reth;
    AETH_h  aeth;
    CRC_h	crc;
}

const bit<64> NB_BUCKET = 256;
const bit<64> NB_BUCKET_SECONDARY = 4096;
const bit<32> NB_BUCKET_SECONDARY_32 = 4096;
const bit<64> main_hashtable_addr = 64w0x400000000000;
const bit<64> secondary_hashtable_addr = 64w0x400000004848;
const bit<64> overflow_hashtable_addr = 64w0x40000004c890;
const bit<64> temp_hashtable_addr = 64w0x40000005e1d0;
const bit<64> server_bucket_size = 72;

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
            0x8915: parse_roce_v1;	// roce
            0x0800: parse_ipv4;
            default: other_accept;
        }
    }

    state parse_roce_v1 {
        pkt.extract(hdr.grh);
        transition parse_ib_transport;
    }

    state parse_ipv4 {
        pkt.extract(hdr.ipv4);
        transition select(hdr.ipv4.protocol) {
            0x11: parse_udp;         // udp packet, possibly rocev2
            default: other_accept; // regular ip packet
        }
    }

    state parse_udp {
        pkt.extract(hdr.udp);
        transition select(hdr.udp.d_port) {
            4791: parse_roce_v2; // rocev2
            default: other_accept;
        }
    }

    state parse_roce_v2 {
        transition parse_ib_transport;
    }

    state parse_ib_transport {
        pkt.extract(hdr.bth);
        transition select(hdr.bth.op_code) {
            0x0c: rdma_read_request;
            0x10: rdma_read_response;
            default: other_accept;
        }
    }

    state rdma_read_request {
        pkt.extract(hdr.reth);
        pkt.extract(hdr.crc);
        metadata.rdma_type = rdma_type_t.READ_REQUEST;
        transition accept;
    }

    state rdma_read_response {
        pkt.extract(hdr.aeth);
        pkt.extract(hdr.resp_metadata);
        metadata.rdma_type = rdma_type_t.READ_RESPONSE;
        transition accept;
    }

    state other_accept {
        metadata.rdma_type = rdma_type_t.OTHERS;
        transition accept;
    }
}

control Ingress(
        inout ingress_headers_t hdr,
        inout ingress_metadata_t metadata,
        in ingress_intrinsic_metadata_t ig_intr_md,
        in ingress_intrinsic_metadata_from_parser_t ig_prsr_md,
        inout ingress_intrinsic_metadata_for_deparser_t ig_dprsr_md,
        inout ingress_intrinsic_metadata_for_tm_t ig_tm_md) {

    action init_metadata_1() {
        metadata.key = (bit<64>)hdr.reth.virtual_address[61:0];
        metadata.bucket = (bit<64>)(hdr.reth.virtual_address[7:0]); // a simple hash function
        metadata.bucket2 = (bit<64>)(hdr.reth.virtual_address[11:0]);
        metadata.bucket_to_probe = (bit<64>)(hdr.reth.virtual_address[7:0]); // % NB_BUCKET
        metadata.dest_table = 0;
    }

    /* ------------------------------- forwarding ------------------------------- */
    action sendto(PortId_t port) {
        ig_tm_md.ucast_egress_port = port;
    }
    action broadcast() {
        ig_tm_md.mcast_grp_a = 1;
        ig_tm_md.bypass_egress = 1;
    }

    action drop() {
        ig_dprsr_md.drop_ctl = 1;
    }

    table port_forward {
        key = { ig_intr_md.ingress_port: exact; }
        actions = { sendto; }
        size = 4;
    }

    table eth_forward {
        key = { hdr.ethernet.dst : exact; }
        actions = { sendto; broadcast; }
        size = 16;
    }

/* --------------------- hash table collision avoidance --------------------- */

    action hashtable_forward_to_secondary() {
        metadata.bucket_to_probe = (bit<64>)metadata.bucket2;
        metadata.dest_table = 1;
    }

    /** this table stores all buckets which are placed out side the main hash
     * table due to hash collision. */
    table hashtable_collision {
        key = { metadata.bucket[29:0] : exact; }
        actions = { hashtable_forward_to_secondary; }
        size = 11000;
    }

    action hashtable_forward_to_overflow(bit<32> third_level_bucket_id) {
        metadata.bucket_to_probe = (bit<64>)third_level_bucket_id;
        metadata.dest_table = 2;
    }

    table hashtable_secondary_overflow {
        key = { metadata.key[63:0] : exact; }
        actions = { hashtable_forward_to_overflow; }
        size = 2500;
    }

    action hashtable_forward_to_temp(bit<32> temp_bucket_id) {
        metadata.bucket_to_probe = (bit<64>)temp_bucket_id;
        metadata.dest_table = 3;
    }

    table hashtable_temp_table {
        key = { metadata.bucket[29:0] : exact; metadata.key[7:0] : ternary; }
        actions = { hashtable_forward_to_temp; }
        size = 256;
    }

    action set_rss_tag(bit<16> qid) {
        hdr.udp.d_port = qid;
    }

    table rss_tag {
        key = { hdr.bth.dest_qp : exact; }
        actions = { set_rss_tag; }
        size = 256;
    }

    DirectCounter<bit<24>>(CounterType_t.PACKETS) value_cache_counter;

    action modify_read_addr(bit<64> new_addr) {
        metadata.cache_hit = 1;
        value_cache_counter.count();
        hdr.reth.virtual_address = new_addr;
    }
    action value_cache_not_found() {
        value_cache_counter.count();
        metadata.cache_hit = 0;
        hdr.ethernet.dst = 48w0x000000008888;
    }

    table value_cache {
        key = { hdr.reth.virtual_address : exact; }
        actions = { modify_read_addr; value_cache_not_found; }
        // currently ad hoc
        default_action = value_cache_not_found;
        counters = value_cache_counter;
        size = 3000; // TODO: increase size to 300,000. Currently it's small because smaller table compiles faster
    }

    // Counter<bit<64>, bit<1>>(1, CounterType_t.PACKETS) resps;
    DirectCounter<bit<64>>(CounterType_t.PACKETS) rdma_counter;

    action rdma_count(bit<8> opcode) {
        rdma_counter.count();
    }

    table rdma_type {
        key = { hdr.bth.op_code : exact; }
        actions = { rdma_count; }
        size = 8;
        counters = rdma_counter;
    }

    DirectCounter<bit<64>>(CounterType_t.PACKETS) cache_hit_miss_counter;
    action count_hit_miss() {
        cache_hit_miss_counter.count();
    }
    table cache_hit_miss {
        key = { metadata.cache_hit : exact; }
        actions = { count_hit_miss; }
        size = 2;
        counters = cache_hit_miss_counter;
    }

    apply {
        init_metadata_1();
        eth_forward.apply();

        rdma_type.apply();

        if (metadata.rdma_type == rdma_type_t.READ_REQUEST 
            && hdr.reth.virtual_address[62:62] == 0  // 62-nd bit: whether inline
            && hdr.reth.virtual_address[63:63] == 1) { // 63-rd bit: whether kv

/* -------------------------------- collision ------------------------------- */
            /** table hashtable_offset and hashtable_collision is for resolving
                hash collision when key-value pairs are inlined.   */
            hashtable_collision.apply();
            hashtable_secondary_overflow.apply();
            hashtable_temp_table.apply();

            hdr.reth.virtual_address[31:0] = metadata.bucket_to_probe[31:0];
            hdr.reth.virtual_address[35:34] = metadata.dest_table;

        } else if (metadata.rdma_type == rdma_type_t.READ_REQUEST
            && hdr.reth.virtual_address[62:62] == 1
            && hdr.reth.virtual_address[63:63] == 1) {

/* ------------------------------- indirection ------------------------------ */

            /** table value_cache is for indirction. */
            switch (value_cache.apply().action_run) {
                value_cache_not_found: { rss_tag.apply(); }
                default: { ; }
            }

            cache_hit_miss.apply();
        }
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
        transition parse_ethernet;
    }

    state parse_ethernet {
        pkt.extract(hdr.ethernet);
        transition select(hdr.ethernet.ether_type) {
            0x8915: parse_roce_v1;	// roce
            0x0800: parse_ipv4;
            default: other_accept;
        }
    }

    state parse_roce_v1 {
        pkt.extract(hdr.grh);
        transition parse_ib_transport;
    }

    state parse_ipv4 {
        pkt.extract(hdr.ipv4);
        transition select(hdr.ipv4.protocol) {
            0x11: parse_udp;         // udp packet, possibly rocev2
            default: other_accept; // regular ip packet
        }
    }

    state parse_udp {
        pkt.extract(hdr.udp);
        transition select(hdr.udp.d_port) {
            4791: parse_roce_v2; // rocev2
            default: other_accept;
        }
    }

    state parse_roce_v2 {
        transition parse_ib_transport;
    }

    state parse_ib_transport {
        pkt.extract(hdr.bth);
        transition select(hdr.bth.op_code) {
            0x0c: rdma_read_request;
            default: other_accept;
        }
    }

    state rdma_read_request {
        pkt.extract(hdr.reth);
        pkt.extract(hdr.crc);
        metadata.rdma_type = rdma_type_t.READ_REQUEST;
        transition accept;
    }

    state other_accept {
        metadata.rdma_type = rdma_type_t.OTHERS;
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

    CRCPolynomial<bit<32>>(0x04C11DB7, true, false, false, 0xFFFFFFFF, 0xFFFFFFFF) p;
    Hash<bit<32>>(HashAlgorithm_t.CUSTOM, p) h1;

    action mult_72(
        in  bit<64> x,
        out bit<64> t1,
        out bit<64> t2) {
        t1 = x << 6;
        t2 = x << 3;
    }
    action hashtable_calculate_offset_2(in bit<64> t0, in bit<64> t1,
                                        in bit<64> t2, out bit<64> result) {
        result = t0 + t1 + t2;
    }
    action add_two(in bit<64> t1, in bit<64> t2, out bit<64> result) {
        result = t1 + t2;
    }
    action sub_two(inout bit<32> x, in bit<32> y) {
        x = x - y;
    }

    apply {
        if(metadata.rdma_type == rdma_type_t.READ_REQUEST 
                // && hdr.reth.virtual_address[62:62] == 0
                // && hdr.reth.virtual_address[63:63] == 1) {
        ) {
/* --------------------------- address calculation -------------------------- */
           //  bit<64> bucket_to_probe = (bit<64>)hdr.reth.virtual_address[31:0];
           //  bit<2> dest_table = hdr.reth.virtual_address[35:34];
           //  bit<64> t1;
           //  bit<64> t2;
           //  // if (dest_table == 1) {
           //  //     // x %= 16
           //  //     bucket_to_probe[63:12] = 0;
           //  // }
           //  mult_72(bucket_to_probe, t1, t2);
           //  bit<64> y;
           //  add_two(t1, t2, y);
           //  bit<64> hashtable_addr;
           //  if (dest_table == 0) {
           //      hashtable_addr = main_hashtable_addr;
           //  } else if (dest_table == 1) {
           //      hashtable_addr = secondary_hashtable_addr;
           //  } else if (dest_table == 2) {
           //      hashtable_addr = overflow_hashtable_addr;
           //  } else if (dest_table == 3) {
           //      hashtable_addr = temp_hashtable_addr;
           //  }
           //  add_two(y, hashtable_addr, hdr.reth.virtual_address);

/* ----------------------------- CRC calculation ---------------------------- */
            bit<32> tmp1;
            tmp1 = h1.get(
                    32w0xFFFFFFFF ++ 32w0xFFFFFFFF ++ hdr.ipv4.version ++ hdr.ipv4.ihl
                    ++ 8w0xFF ++ hdr.ipv4.total_len ++ hdr.ipv4.identification
                    ++ hdr.ipv4.flags ++ hdr.ipv4.frag_offset ++ 8w0xFF
                    ++ hdr.ipv4.protocol ++ 16w0xFFFF
                    ++ hdr.ipv4.src_addr ++ hdr.ipv4.dst_addr
                    ++ hdr.udp.s_port ++ hdr.udp.d_port ++ hdr.udp.len ++ 16w0xFFFF
                    ++ hdr.bth.op_code ++ hdr.bth.ignore_1 ++ 8w0xFF
                    ++ hdr.bth.dest_qp ++ hdr.bth.a ++ hdr.bth.reserved_2 ++ hdr.bth.psn
                    ++ hdr.reth.virtual_address ++ hdr.reth.r_key ++ hdr.reth.dma_len);
            hdr.crc.crc[7:0] = tmp1[31:24];
            hdr.crc.crc[15:8] = tmp1[23:16];
            hdr.crc.crc[23:16] = tmp1[15:8];
            hdr.crc.crc[31:24] = tmp1[7:0];
        }
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

Pipeline (
    IngressParser(),Ingress(),IngressDeparser(),
    EgressParser(),Egress(),EgressDeparser()
) pipe;

Switch(pipe) main;
