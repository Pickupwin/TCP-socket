#include<core.p4>
#include<tna.p4>

/*header definions*/

struct ingress_headers_t{
}

struct ingress_metadata_t{}

parser IngressParser(packet_in pkt,
	out ingress_headers_t hdr,
	out ingress_metadata_t metadata,
	out ingress_intrinsic_metadata_t ig_intr_md)
{
	state start{
		pkt.extract(ig_intr_md);
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
	action sendto(PortId_t id) {
		ig_tm_md.ucast_egress_port = id;
	}
	table port_forward {
		key = {
			ig_intr_md.ingress_port: exact;
		}
		actions = { sendto; }
	}
	apply{
		port_forward.apply();
		// ad hoc forwarding
	 	// if (ig_intr_md.ingress_port == 188) {
	 	// 	ig_tm_md.ucast_egress_port = 184;
	 	// } else {
	 	// 	ig_tm_md.ucast_egress_port = 188;
	 	// }
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
