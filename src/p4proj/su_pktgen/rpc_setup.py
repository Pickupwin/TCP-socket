
import os
import sys
import time

sys.path.append("{}/lib/python2.7/site-packages/tofino".format(os.environ["SDE_INSTALL"]))


import bfrt_grpc.client as gc
from scapy.all import Ether


grpc_addr = "localhost:50052"
p4_name = "su_pktgen"
timer_app_id = 1

def make_port(pipe, local_port):
    return (pipe << 7) | local_port

def pgen_port(pipe_id):
    pipe_local_port=68
    return make_port(pipe_id, pipe_local_port)


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

    app_id = timer_app_id
    pktlen = 100
    src_port = pgen_port(0)
    p_count = 2
    b_count = 4
    buff_offset = 144
    out_port = 188
    
    my_pkt = Ether(
        # port 188
        # dst = '08:c0:eb:33:31:74',
        # port 184
        # dst = 'b8:ce:f6:83:b2:ea',
        dst = '00:01:02:03:04:05',
        src = '00:06:07:08:09:0a',
        type = 0x88cc
    )
    my_pkt = my_pkt/("A"*(pktlen-len(my_pkt)))


    pktgen_app_cfg_table = bfrt_info.table_get("$PKTGEN_APPLICATION_CFG")
    pktgen_pkt_buffer_table = bfrt_info.table_get("$PKTGEN_PKT_BUFFER")
    pktgen_port_cfg_table = bfrt_info.table_get("$PKTGEN_PORT_CFG")
    
    pktgen_port_cfg_table.entry_add(
        target,
        [pktgen_port_cfg_table.make_key(
            [gc.KeyTuple('dev_port', src_port)]
        )],
        [pktgen_port_cfg_table.make_data(
            [gc.DataTuple('pktgen_enable', bool_val=True)]
        )]
    )

    pktgen_app_cfg_data = pktgen_app_cfg_table.make_data([
        gc.DataTuple('timer_nanosec', 100),
        gc.DataTuple('app_enable', bool_val=False),
        gc.DataTuple('pkt_len', pktlen),
        gc.DataTuple('pkt_buffer_offset', buff_offset),
        gc.DataTuple('pipe_local_source_port', src_port),
        gc.DataTuple('increment_source_port', bool_val=False),
        gc.DataTuple('batch_count_cfg', b_count-1),
        gc.DataTuple('packets_per_batch_cfg', p_count-1),
        gc.DataTuple('ibg', 1),
        gc.DataTuple('ibg_jitter', 0),
        gc.DataTuple('ipg', 1000),
        gc.DataTuple('ipg_jitter', 500),
        gc.DataTuple('batch_counter', 0),
        gc.DataTuple('pkt_counter', 0),
        gc.DataTuple('trigger_counter', 0)
    ], '$PKTGEN_TRIGGER_TIMER_ONE_SHOT')
    pktgen_app_cfg_table.entry_add(
        target,
        [pktgen_app_cfg_table.make_key(
            [gc.KeyTuple('app_id', timer_app_id)]
        )],
        [pktgen_app_cfg_data]
    )

    resp = pktgen_app_cfg_table.entry_get(
        target,
        [pktgen_app_cfg_table.make_key(
            [gc.KeyTuple('app_id', timer_app_id)]
        )],
        {"from_hw": True},
        pktgen_app_cfg_table.make_data([
            gc.DataTuple('batch_counter'),
            gc.DataTuple('pkt_counter'),
            gc.DataTuple('trigger_counter')
        ], '$PKTGEN_TRIGGER_TIMER_ONE_SHOT', get=True)
    )
    data_dict = next(resp)[0].to_dict()
    tri_value = data_dict["trigger_counter"]
    batch_value = data_dict["batch_counter"]
    pkt_value = data_dict["pkt_counter"]
    print(tri_value, batch_value, pkt_value)

    pktgen_pkt_buffer_table.entry_add(
        target,
        [pktgen_pkt_buffer_table.make_key([
            gc.KeyTuple('pkt_buffer_offset', buff_offset),
            gc.KeyTuple('pkt_buffer_size', pktlen)
        ])],
        [pktgen_pkt_buffer_table.make_data(
            [gc.DataTuple('buffer', str(my_pkt))]
        )]
    )

    pktgen_app_cfg_table.entry_mod(
        target,
        [pktgen_app_cfg_table.make_key(
            [gc.KeyTuple('app_id', timer_app_id)]
        )],
        [pktgen_app_cfg_table.make_data(
            [gc.DataTuple('app_enable', bool_val=True)],
            '$PKTGEN_TRIGGER_TIMER_ONE_SHOT'
        )]
    )

    time.sleep(0.01)

    resp = pktgen_app_cfg_table.entry_get(
        target,
        [pktgen_app_cfg_table.make_key(
            [gc.KeyTuple('app_id', timer_app_id)]
        )],
        {"from_hw": True},
        pktgen_app_cfg_table.make_data([
            gc.DataTuple('batch_counter'),
            gc.DataTuple('pkt_counter'),
            gc.DataTuple('trigger_counter')
        ], '$PKTGEN_TRIGGER_TIMER_ONE_SHOT', get=True)
    )
    data_dict = next(resp)[0].to_dict()
    tri_value = data_dict["trigger_counter"]
    batch_value = data_dict["batch_counter"]
    pkt_value = data_dict["pkt_counter"]
    print(tri_value, batch_value, pkt_value)