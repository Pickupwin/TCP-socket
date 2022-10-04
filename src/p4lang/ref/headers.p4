/** header definions **/

header ethernet_h {
    // bit<64> key;
    // bit<32> ignored;
    bit<48> dst;
    bit<48> src;
    bit<16> ether_type;
}

header ipv4_h {
    bit<4>	version;
    bit<4>	ihl;
    bit<8>	diffserv;
    bit<16>	total_len;
    bit<16>	identification;
    bit<3>	flags;
    bit<13>	frag_offset;
    bit<8>	ttl;
    bit<8>	protocol;
    bit<16>	checksum;
    bit<32>	src_addr;
    bit<32>	dst_addr;
}
header udp_h {
    bit<16>	s_port;
    bit<16>	d_port;
    bit<16>	len;
    bit<16>	checksum;
}
header GRH_h {
    bit<4>	ip_ver;
    bit<8>	t_class;
    bit<20>	flow_label;
    bit<16>	pay_len;
    bit<8>	nxt_hdr;
    bit<8>	hop_limit;
    bit<128>	s_gid;
    bit<128>	d_gid;
}
header BTH_h {
    bit<8>	op_code;

    bit<24>	ignore_1;
    //	bit<1>	se;
    //	bit<1>	m;
    //	bit<2>	pad_cnt;
    //	bit<4>	t_ver;
    //	bit<16>	p_key;

    bit<8>	reserved_1;
    bit<24>	dest_qp;
    bit<1>	a;
    bit<7>	reserved_2;
    bit<24>	psn;
}
header AETH_h {
    bit<8>	syndrome;
    bit<24> msn;
}
header RETH_h {
    // before switch, this field contains **key**
    // after switch, this field contains **read address**
    bit<64> virtual_address;

    bit<32> r_key;
    bit<32> dma_len;
}
header CRC_h {
    bit<32> crc;
}

enum roce_version_t {
    ROCE_v1,
    ROCE_v2
}

enum rdma_type_t {
    READ_REQUEST,
    READ_RESPONSE,
    OTHERS
}
