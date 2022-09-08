#include "setup_ib.h"

#include "ib.h"
#include "debug.h"
#include "sock.h"

#define SOCK_SYNC_MSG "sync"

#define SERVER_IP "10.129.196.139"
const uint16_t SOCK_PORT=2345;

struct IBRes ib_res;

int sock_recv_qp_info(int fd, struct QPInfo *info){
    struct QPInfo tmp_info;
    int ret=Recv_n(fd, (char *)&tmp_info, sizeof(struct QPInfo));
    check(ret==sizeof(struct QPInfo), "recv qp_info error.");
    info->lid=ntohs(tmp_info.lid);
    info->qp_num=ntohl(tmp_info.qp_num);
    return 0;
error:
    return -1;
}

int sock_send_qp_info(int fd, struct QPInfo *info){
    struct QPInfo tmp_info;
    tmp_info.lid=htons(info->lid);
    tmp_info.qp_num=htons(info->qp_num);
    int ret=Send_n(fd, (char *)&tmp_info, sizeof(struct QPInfo));
    check(ret==sizeof(struct QPInfo), "send qp_info error");
    return 0;
error:
    return -1;
}


int setup_ib(){
    
    int ret=0;
    
    memset(&ib_res, 0, sizeof(struct IBRes));
    
    struct ibv_device **dev_list=NULL;
    dev_list=ibv_get_device_list(NULL);
    check(dev_list, "Failed to get ib device list.");
    
    ib_res.ctx=ibv_open_device(*dev_list);
    check(ib_res.ctx, "Failed to open ib device");
    
    ib_res.pd=ibv_alloc_pd(ib_res.ctx);
    check(ib_res.pd, "Failed to alloc protection domain.");
    
    ret=ibv_query_port(ib_res.ctx, IB_PORT, &ib_res.port_attr);
    check(ret==0, "Failed to query IB port info.");
    
    ib_res.ib_buf_size=MSG_SIZE*CUR_MSGS;
    ib_res.ib_buf=(char *)memalign(4096, ib_res.ib_buf_size);
    check(ib_res.ib_buf, "Failed to alloc ib_buf.");
    
    ib_res.mr=ibv_reg_mr(ib_res.pd, (void *)ib_res.ib_buf,
                    ib_res.ib_buf_size,
                    IBV_ACCESS_LOCAL_WRITE |
                    IBV_ACCESS_REMOTE_READ |
                    IBV_ACCESS_REMOTE_WRITE);
    check(ib_res.mr, "Failed to register mr.");
    
    ret=ibv_query_device(ib_res.ctx, &ib_res.dev_attr);
    check(ret==0, "Failed to query device.");
    
    ib_res.cq=ibv_create_cq(ib_res.ctx, ib_res.dev_attr.max_cqe, NULL, NULL, 0);
    check(ib_res.cq, "Failed to create cq.");
    
    struct ibv_qp_init_attr qp_init_attr={
        .send_cq=ib_res.cq,
        .recv_cq=ib_res.cq,
        .cap={
            .max_send_wr=ib_res.dev_attr.max_qp_wr,
            .max_recv_wr=ib_res.dev_attr.max_qp_wr,
            .max_send_sge=1,
            .max_recv_sge=1,
        },
        .qp_type=IBV_QPT_RC,
    };
    
    ib_res.qp=ibv_create_qp(ib_res.pd, &qp_init_attr);
    check(ib_res.qp, "Failed to create qp.");
    
    ret=connect_qp_server();
    check(ret==0, "Failed to connect qp");
    
    ibv_free_device_list(dev_list);
    return 0;
    
error:
    if(dev_list)
        ibv_free_device_list(dev_list);
    return -1;
}

int connect_qp_server(){
    
    int ret=0;
    int server_fd, client_fd;
    
    struct sockaddr_in my_addr=Get_addr(INADDR_ANY, htons(SOCK_PORT));
    server_fd=Open_server_socket((struct sockaddr *)&my_addr, 5);
    check(server_fd>0, "Failed to open server socket.");
    
    struct sockaddr_in remote_addr;
    socklen_t sin_size=sizeof(struct sockaddr_in);
    if((client_fd=accept(server_fd, (struct sockaddr *)&remote_addr, sin_size))<=0){
        perror("Failed to accept client.");
        goto error;
    }
    
    struct QPInfo local_qp_info, remote_qp_info;
    
    local_qp_info.lid=ib_res.port_attr.lid;
    local_qp_info.qp_num=ib_res.qp->qp_num;
    
    ret=sock_recv_qp_info(client_fd, &remote_qp_info);
    check(ret==0, "Failed to recv client qp info.");
    
    ret=sock_send_qp_info(client_fd, &local_qp_info);
    check(ret==0, "Failed to send server qp info.");
    
    ret=modify_qp_to_rts(ib_res.qp, remote_qp_info.qp_num, remote_qp_info.lid);
    check(ret==0, "Failed to modify qp to rts.");
    
    char sync_buf[]={'s','y','n','c','\0'}
    //sync_server
    ret=Recv_n(client_fd, sync_buf, sizeof(SOCK_SYNC_MSG));
    check(ret==sizeof(SOCK_SYNC_MSG), "Failed to recv sync from client.");
    ret=Send_n(client_fd, sync_buf, sizeof(SOCK_SYNC_MSG));
    check(ret==sizeof(SOCK_SYNC_MSG), "Failed to send sync to client.");
    
    close(client_fd);
    close(server_fd);
    
    return 0;
    
error:
    if(client_fd>0)
        close(client_fd);
    if(server_fd>0)
        close(server_fd);
    return -1;
}

int connect_qp_client(){
    
    int ret;
    int client_fd;
    
    struct sockaddr_in remote_addr=Get_addr(inet_addr(SERVER_IP), htons(SOCK_PORT));
    
    if((client_fd=socket(PF_INET, SOCK_STREAM, 0))<0){
        perror("socker failed!");
        goto error;
    }
    
    if(connect(client_fd, (struct sockaddr *)&remote_addr, sizeof(struct sockaddr))<0){
        perror("connect failed!");
        goto error;
    }
    
    struct QPInfo local_qp_info, remote_qp_info;
    
    local_qp_info.lid=ib_res.port_attr.lid;
    local_qp_info.qp_num=ib_res.qp->qp_num;
    
    ret=sock_send_qp_info(client_fd, &local_qp_info);
    check(ret==0, "Failed to send client qp info.");
    ret=sock_send_qp_info(client_fd, &remote_qp_info);
    check(ret==0, "Failed to recv client qp info.");
    
    ret=modify_qp_to_rts(ib_res.qp, remote_qp_info.qp_num, remote_qp_info.lid);
    check(ret==0, "Failed to modify qp to rts.");
    
    char sync_buf[]={'s','y','n','c','\0'}
    //sync_server
    ret=Recv_n(client_fd, sync_buf, sizeof(SOCK_SYNC_MSG));
    check(ret==sizeof(SOCK_SYNC_MSG), "Failed to recv sync from client.");
    ret=Send_n(client_fd, sync_buf, sizeof(SOCK_SYNC_MSG));
    check(ret==sizeof(SOCK_SYNC_MSG), "Failed to send sync to client.");
    
    close(client_fd);
    
    return 0;

error:
    if(client_fd>0)
        close(client_fd);
    return -1;
}

void close_ib_connection(){
    if(ib_res.qp)
        ibv_destroy_qp(ib_res.qp);
    if(ib_res.cq)
        ibv_destroy_qp(ib_res.qp);
    if(ib_res.mr)
        ibv_dereg_mr(ib_res.mr);
    if(ib_res.pd)
        ibv_dealloc_pd(ib_res.pd);
    if(ib_res.ctx)
        ibv_close_device(ib_res.ctx);
    
    if(ib_res.ib_buf)
        free(ib_res.ib_buf);
}