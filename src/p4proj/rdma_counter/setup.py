p4 = bfrt.rdma_counter.pipe

def clear_all():
    global p4
    for table in p4.info(return_info=True, print_info=False):
        if table['type'] in ['MATCH_DIRECT', 'MATCH_INDIRECT_SELECTOR', 'SELECTOR', 'ACTION_PROFILE']:
            print("Clearing table {}".format(table['full_name']))
            for entry in table['node'].get(regex=True):
                entry.remove()
clear_all()

eth_forward=p4.Ingress.eth_forward
eth_forward.add_with_sendto(dst_addr=0xb8cef683b2ea, port=184)
eth_forward.add_with_sendto(dst_addr=0x08c0eb333174, port=188)
