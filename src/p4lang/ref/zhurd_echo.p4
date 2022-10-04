#include<core.p4>
#include<tna.p4>

/*header definions*/

header ethernet_h{
	bit<48> dst_addr;
	bit<48> src_addr;
	bit<16> ether_type;
}

struct ingress_headers_t{
	ethernet_h ethernet;
}

struct ingress_metadata_t{}

parser IngressParser(packet_in pkt,
	out ingress_headers_t hdr,
	out ingress_metadata_t metadata,
	out ingress_intrinsic_metadata_t ig_intr_md)
{
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
)
{
	DirectCounter<bit<64>>(CounterType_t.PACKETS_AND_BYTES) ipv4_host_stats;
	action send(PortId_t port){
		ig_tm_md.ucast_egress_port = port;
		ipv4_host_stats.count();
	}
	

	action drop(){
		ig_dprsr_md.drop_ctl = 1;
		ipv4_host_stats.count();
	}

	apply{
		bit<48> t;
		if(hdr.ethernet.isValid()) {
			t = hdr.ethernet.dst_addr;
			hdr.ethernet.dst_addr = hdr.ethernet.src_addr;
			hdr.ethernet.src_addr = t;
			ig_tm_md.ucast_egress_port = ig_intr_md.ingress_port;
		} else {
			drop();
		}
	}
}

control IngressDeparser(packet_out pkt,
	inout ingress_headers_t hdr,
	in ingress_metadata_t metadata,
	in ingress_intrinsic_metadata_for_deparser_t ig_dprsr_md
)
{
	apply{
		pkt.emit(hdr);
	}
}

struct my_egress_headers_t{}
struct my_egress_metadata_t{}

parser EgressParser(packet_in pkt,
	out my_egress_headers_t hdr,
	out my_egress_metadata_t meta,
	out egress_intrinsic_metadata_t eg_intr_md)
{
	state start{
		pkt.extract(eg_intr_md);
		transition accept;
	}
}

control Egress(
	inout my_egress_headers_t hdr,
	inout my_egress_metadata_t meta,
	in egress_intrinsic_metadata_t eg_intr_md,
	in egress_intrinsic_metadata_from_parser_t eg_prsr_md,
	inout egress_intrinsic_metadata_for_deparser_t eg_dprsr_md,
	inout egress_intrinsic_metadata_for_output_port_t eg_oport_md)
{
	// DirectCounter<bit<32>>(CounterType_t.PACKETS)packet_size_stats;

	// action just_count(){packet_size_stats.count();}

	// table packet_size_hist{
	// 	key={eg_intr_md.pkt_length:range;}
	// 	actions={just_count;}
	// 	counters=packet_size_stats;
	// 	size=512;
	// }
	// apply{packet_size_hist.apply();}
	apply { }
}

control EgressDeparser(packet_out pkt,
	inout my_egress_headers_t hdr,
	in my_egress_metadata_t meta,
	in egress_intrinsic_metadata_for_deparser_t eg_dprsr_md)
{
	apply{
		pkt.emit(hdr);
	}
}


Pipeline
(IngressParser(),Ingress(),IngressDeparser(),
EgressParser(),Egress(),EgressDeparser()
)pipe;

Switch(pipe) main;
