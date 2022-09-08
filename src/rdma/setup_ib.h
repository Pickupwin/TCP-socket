#include <infiniband/verbs.h>

extern const size_t MSG_SIZE;
extern const size_t CUR_MSGS;

struct IBRes{
    
    struct ibv_context *ctx;
    struct ibv_pd *pd;
    struct ibv_mr *mr;
    struct ibv_cq *cq;
    struct ibv_qp *qp;
    struct ibv_port_attr port_attr;
    struct ibv_device_attr dev_attr;
    
    char *ib_buf;
    size_t ib_buf_size;
    
};

extern struct IBRes ib_res;


int setup_ib();
void close_ib_connection();

int connect_qp_server();
int connect_qp_client();
