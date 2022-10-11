
clear_all()

mirror.session_create(
    mirror.MirrorSessionInfo_t(
        mir_type=mirror.MirrorType_e.PD_MIRROR_TYPE_NORM,
        direction=mirror.Direction_e.PD_DIR_BOTH,
        mir_id=5, egr_port=188, egr_port_v=True,
        max_pkt_len=16384
    )
)

conn_mgr.complete_operations()