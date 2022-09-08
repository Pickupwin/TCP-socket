#include "debug.h"
#include "ib.h"
#include "setup_ib.h"
#include <string.h>

const size_t NUM_MSGS=1000000u;

int run_client(){
    
    unsigned long long cksum, flen;
    check(Gen_cksum(fname, &cksum, &flen), "Gen_cksum failed!");
    
    FILE *pFile=fopen(fname, "rb");
    check(pFile, "fopen failed!");
    
    int ret=0, n;
    
    int num_wc=20;
    struct ibv_wc *wc=NULL;
    
    wc=(struct ibv_wc *)calloc(num_wc, sizeof(struct ibv_wc));
    check(wc, "Failed to alloc wc");
    
    struct ibv_qp *qp=ib_res.qp;
    struct ibv_cq *cq=ib_res.cq;
    
    uint32_t lkey=ib_res.mr->lkey;
    
    char *buf_ptr=ib_res.ib_buf;
    
    for(size_t i=0u;i<NUM_MSGS;++i){
        ret=post_send(MSG_SIZE, lkey, (uint64_t)buf_ptr, qp, buf_ptr);
        check(ret==0, "Failed to post recv");
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
    
    
    free(wc);
    return 0;

error:
    if(wc)  free(wc);
    return -1;
}

int main(int argc, char *argv[]){
    
    if(argc!=3){
        fprintf(stderr, "arg error!\n");
        return -1;
    }
    
    if(strlen(argv[2])>32){
        fprintf(stderr, "target file name too long!\n");
        return -1;
    }
    
    int ret=0;
    
    ret=setup_ib();
    check(ret==0, "Failed to setup IB.");
    
    ret=run_client(argv[1], argv[2]);
    check(ret==0, "Failed to run client.");
    
error:
    close_ib_connection();
    return ret;
}