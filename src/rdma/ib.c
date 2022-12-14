

#include "ib.h"
#include "debug.h"


int modify_qp_to_rts(struct ibv_qp *qp, uint32_t qp_num, union ibv_gid gid){
    
    printf("qp_num=%u, gid=%llu,%llu\n", qp_num, gid.global.subnet_prefix, gid.global.interface_id);
    for(int i=0;i<16;++i)   printf("%u ", gid.raw[i]);
    puts("");
    
    int ret=0;
    
    {
        //INIT
        
        struct ibv_qp_attr qp_attr={
            .qp_state=IBV_QPS_INIT,
            .pkey_index=0,
            .port_num=IB_PORT,
            .qp_access_flags=IBV_ACCESS_LOCAL_WRITE |
                            IBV_ACCESS_REMOTE_READ |
                            IBV_ACCESS_REMOTE_ATOMIC |
                            IBV_ACCESS_REMOTE_WRITE,
        };
        
        ret=ibv_modify_qp(qp, &qp_attr,
                        IBV_QP_STATE | IBV_QP_PKEY_INDEX |
                        IBV_QP_PORT | IBV_QP_ACCESS_FLAGS);
        check(ret==0, "Failed to modify qp to INIT");
        
    }
    puts("INIT Done.");
    
    {
        //RTR
        struct ibv_qp_attr qp_attr={
            .qp_state=IBV_QPS_RTR,
            .path_mtu=IB_MTU,
            .dest_qp_num=qp_num,
            .rq_psn=0,
            .max_dest_rd_atomic=1,
            .min_rnr_timer=12,
            .ah_attr={
                .is_global=1,
                .port_num=IB_PORT,
                .grh={
                    .sgid_index=GID_INDEX,
                    .dgid=gid,
                    .flow_label=0,
                    .traffic_class=0,
                }
            }
        };
        
        ret=ibv_modify_qp(qp, &qp_attr,
                        IBV_QP_STATE | IBV_QP_AV |
                        IBV_QP_PATH_MTU | IBV_QP_DEST_QPN |
                        IBV_QP_RQ_PSN | IBV_QP_MAX_DEST_RD_ATOMIC |
                        IBV_QP_MIN_RNR_TIMER);
        check(ret==0, "Failed to change qp to rtr.");
    }
    puts("RTR Done.");
    
    {
        //RTS
        
        struct ibv_qp_attr qp_attr={
            .qp_state=IBV_QPS_RTS,
            .timeout=14,
            .retry_cnt=7,
            .rnr_retry=7,
            .sq_psn=0,
            .max_rd_atomic=1,
        };
        
        ret=ibv_modify_qp(qp, &qp_attr,
                        IBV_QP_STATE | IBV_QP_TIMEOUT |
                        IBV_QP_RETRY_CNT | IBV_QP_RNR_RETRY |
                        IBV_QP_SQ_PSN | IBV_QP_MAX_QP_RD_ATOMIC);
        check(ret==0, "Failed to modify qp to RTS.");
    }
    puts("RTS Done.");
    
    return 0;

error:
    return -1;
    
}


int post_send(uint32_t req_size, uint32_t lkey, uint64_t wr_id, uint32_t imm_data, struct ibv_qp *qp, char *buf)
{
    int ret=0;
    struct ibv_send_wr *bad_send_wr;
    struct ibv_sge list={
        .addr=(uintptr_t) buf,
        .length=req_size,
        .lkey=lkey,
    };
    struct ibv_send_wr send_wr={
        .wr_id=wr_id,
        .sg_list=&list,
        .num_sge=1,
        .opcode=IBV_WR_SEND_WITH_IMM,
        .send_flags=IBV_SEND_SIGNALED,
        .imm_data=htonl(imm_data)
    };
    ret=ibv_post_send(qp, &send_wr, &bad_send_wr);
    return ret;
}

int post_recv(uint32_t req_size, uint32_t lkey, uint64_t wr_id, struct ibv_qp *qp, char *buf){
    int ret=0;
    struct ibv_recv_wr *bad_recv_wr;
    struct ibv_sge list={
        .addr=(uintptr_t)buf,
        .length=req_size,
        .lkey=lkey
    };
    struct ibv_recv_wr recv_wr={
        .wr_id=wr_id,
        .sg_list=&list,
        .num_sge=1
    };
    ret=ibv_post_recv(qp, &recv_wr, &bad_recv_wr);
    return ret;
}