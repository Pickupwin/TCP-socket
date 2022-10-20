
import os
import sys

sys.path.append("{}/lib/python2.7/site-packages/tofino".format(os.environ["SDE_INSTALL"]))

import bfrt_grpc.client as gc

grpc_addr = "localhost:50052"
p4_name = "rdma_counter"

conf_forward=[
    {
        'dst-mac': 0xb8cef683b2ea,
        'eg-port': 184
    },
    {
        'dst-mac': 0x08c0eb333174,
        'eg-port': 188
    }
]

def del_entries(table, target):
    
    resp = table.entry_get(target, None, {"from_hw":True})
    for data, key in resp:
        table.entry_del(target, [key])

if __name__ == "__main__":
    interface = gc.ClientInterface(
        grpc_addr,
        client_id = 0,
        device_id = 0,
        notifications = None,
        perform_subscribe = True
    )
    interface.bind_pipeline_config(p4_name)

    target = gc.Target(device_id=0, pipe_id=0xffff)
    bfrt_info = interface.bfrt_info_get()

    forward_table = bfrt_info.table_get("Ingress.eth_forward")

    del_entries(forward_table, target)

    for entry in conf_forward:
        dst_mac = entry['dst-mac']
        eg_port = entry['eg-port']
        forward_table_bfrt_key = forward_table.make_key(
            [gc.KeyTuple('hdr.eth_hdr.dst_addr', dst_mac)]
        )
        forward_table_bfrt_data = forward_table.make_data(
            [gc.DataTuple('port', eg_port)],
            "Ingress.sendto"
        )
        forward_table.entry_add(
            target,
            [forward_table_bfrt_key],
            [forward_table_bfrt_data]
        )