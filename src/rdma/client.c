#include "debug.h"
#include "ib.h"
#include "setup_ib.h"
#include <string.h>
#include <stdlib.h>

const size_t NUM_MSGS=1000u;

int run_client(){
    
    int ret=0, n;
    
    int num_wc=20;
    struct ibv_wc *wc=NULL;
    
    wc=(struct ibv_wc *)calloc(num_wc, sizeof(struct ibv_wc));
    check(wc, "Failed to alloc wc");
    
    struct ibv_qp *qp=ib_res.qp;
    struct ibv_cq *cq=ib_res.cq;
    
    uint32_t lkey=ib_res.mr->lkey;
    
    char *buf_ptr=ib_res.ib_buf;
    
    struct timeval start, end;
    
    gettimeofday(&start, NULL);
    
    for(size_t i=0u;i<NUM_MSGS;++i){
        ret=post_send(MSG_SIZE, lkey, (uint64_t)buf_ptr, MSG_REGULAR, qp, buf_ptr);
        check(ret==0, "Failed to post send");
        for(int flag=1;flag;){
            n=ibv_poll_cq(cq, num_wc, wc);
            check(n>=0, "Failed to poll cq");
            for(int i=0;i<n;++i){
                check(wc[i].status==IBV_WC_SUCCESS, "failed wc");
                if(wc[i].opcode==IBV_WC_SEND){
                    flag=0;
                    // ret=post_recv(MSG_SIZE, lkey, wc[i].wr_id, MSG_REGULAR, qp, (char *)wc[i].wr_id);
                    // check(ret==0, "Failed to post send");
                }
            }
        }
    }
    for(size_t i=0u;i<NUM_MSGS;++i){
        ret=post_send(MSG_SIZE, lkey, (uint64_t)buf_ptr, MSG_REGULAR, qp, buf_ptr);
        check(ret==0, "Failed to post send");
    }
    
    // for(size_t i=0u;i<NUM_MSGS;){
    //     n=ibv_poll_cq(cq, num_wc, wc);
    //     check(n>=0, "Failed to poll cq");
    //     for(int j=0;j<n;++j){
    //         check(wc[j].status==IBV_WC_SUCCESS, "failed wc");
    //         if(wc[j].opcode==IBV_WC_SEND){
    //             ++i;
    //         }
    //     }
    // }
    
    // for(size_t i=0u;i<MSG_SIZE;++i) buf_ptr[i]='B';
    
    // ret=post_recv(MSG_SIZE, lkey, (uint64_t)buf_ptr, qp, buf_ptr);
    // check(ret==0, "Failed to post recv");
    
    // usleep(100000u);
    
    // ret=post_send(MSG_SIZE, lkey, (uint64_t)buf_ptr, MSG_REGULAR, qp, buf_ptr);
    // check(ret==0, "Failed to post send");
    
    // for(size_t i=0u;i<2u;){
    //     n=ibv_poll_cq(cq, num_wc, wc);
    //     check(n>=0, "Failed to poll cq");
    //     for(int j=0;j<n;++j){
    //         check(wc[j].status==IBV_WC_SUCCESS, "Got failed wc");
    //         i+=(wc[j].opcode==IBV_WC_RECV || wc[j].opcode==IBV_WC_SEND);
    //         printf("poll %d opcode:%u (IBV_WC_RECV=%u, IBV_WC_SEND=%u)\n", j, wc[j].opcode, IBV_WC_RECV, IBV_WC_SEND);
    //         if(wc[j].opcode==IBV_WC_RECV){
    //             for(size_t t=0u;t<10u;++t)  printf("%c", ((char *)wc[j].wr_id)[t]);
    //             puts("");
    //         }
    //     }
    // }
    
    gettimeofday(&end, NULL);
    
    printf("start: %d.%d\n", start.tv_sec, start.tv_usec);
    printf("end  : %d.%d\n", end.tv_sec, end.tv_usec);
    
    
    free(wc);
    return 0;

error:
    if(wc)  free(wc);
    return -1;
}

int main(){
    
    int ret=0;
    
    ret=setup_ib(0);
    check(ret==0, "Failed to setup IB.");
    printf("setup_ib OK\n");
    
    ret=run_client();
    check(ret==0, "Failed to run client.");
    
error:
    close_ib_connection();
    return ret;
}