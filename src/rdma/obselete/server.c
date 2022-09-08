#include "debug.h"
#include "ib.h"
#include "setup_ib.h"
#include <string.h>

#define FILE_HEAD "SU-RDMA-FILE-HEAD"
#define FNAME_SIZE 32

enum State{
    INIT=0,
    RECV,
    SUCCESS,
    FAIL,
} server_state;

int Gen_cksum(const char *f, unsigned long long *c, unsigned long long *l){
    sprintf(Buf, "cksum %s > tmp.txt", f);
    system(Buf);
    FILE *pFile=fopen("tmp.txt", "rb");
    if(!pFile)
        return 0;
    fscanf(pFile, "%llu%llu", c, l);
    fclose(pFile);
    system("rm tmp.txt -rf");
    return 1;
}

void run_state_machine(char *msg_ptr){
    static char name[FNAME_SIZE+1];
    static unsigned long long cksum, flen, cflen=0ull, rcksum, rflen;
    static FILE *pFile;
    switch(server_state){
        case INIT:
            if(strcmp(msg_ptr, FILE_HEAD)==0){
                msg_ptr+=sizeof(FILE_HEAD);
                memcpy(name, msg_ptr, FNAME_SIZE);name[FNAME_SIZE]='\0';
                msg_ptr+=sizeof(FNAME_SIZE);
                if(sscanf(msg_ptr, "%llu%llu", &cksum, &flen)!=2){
                    server_state=FAIL;
                    break;
                }
                pFile=fopen(name, "wb");
                if(!pFile){
                    server_state=FAIL;
                    break;
                }
                server_state=RECV;
            }
            break;
        case RECV:
            fwrite(msg_ptr, sizeof(char), min(MSG_SIZE, flen-cflen), pFile);
            cflen+=MSG_SIZE;
            if(cflen>=flen){
                fclose(pFile);
                if(Gen_cksum(name, &rcksum, &rflen) && rcksum==cksum && rflen==flen)
                    server_state=SUCCESS;
                else
                    server_state=FAIL;
            }
            break;
        default:
            break;
    }    
}

int run_server(){
    
    server_state=INIT;
    
    int ret=0, n;
    
    int num_wc=20;
    struct ibv_wc *wc=NULL;
    
    struct ibv_qp *qp=ib_res.qp;
    struct ibv_cq *cq=ib_res.cq;
    
    uint32_t lkey=ib_res.mr->lkey;
    
    char *buf_ptr=ib_res.ib_buf;
    
    for(int i=0;i<NUM_MSGS;++i){
        ret=post_recv(MSG_SIZE, lkey, (uint64_t)buf_ptr, qp, buf_ptr);
        check(ret==0, "Failed to post recv.");
        buf_ptr+=MSG_SIZE;
    }
    
    wc=(struct ibv_wc *)calloc(num_wc, sizeof(struct ibv_wc));
    check(wc, "Failed to alloc wc");
    
    while(1){
        n=ibv_poll_cq(cq, num_wc, wc);
        check(n>=0, "Failed to poll cq.");
        for(int i=0;i<n;++i){
            if(wc[i].status!=IBV_WC_SUCCESS){
                if(wc[i].opcode==IBV_WC_SEND){
                    check(0, "send failed status: %s", ibv_wc_status_str(wc[i].status));
                }
                else if(wc[i].opcode==IBV_WC_RECV){
                    check(0, "recv failed status: %s", ibv_wc_status_str(wc[i].status));
                }
                else{
                    check(0, "unknown failed status: %s", ibv_wc_status_str(wc[i].status));
                }
                continue;
            }
            if(wc[i].opcode==IBV_WC_RECV){
                run_state_machine((char *)wc[i].wr_id);
                if(server_state==RECV){
                    ret=post_send(0, lkey, 0, MSG_REGULAR, qp, ib_res.ib_buf);
                    check(ret==0, "Failed to response the client.");
                }
                if(server_state==SUCCESS || server_state==FAIL) break;
            }
        }
    }
    
    ret=post_send(0, lkey, 0, server_state==SUCCESS?MSG_SUCCESS:MSG_FAILED, qp, ib_res.ib_buf);
    check(ret==0, "Failed to response the client.");

error:
    if(wc)  free(wc);
    return -1;
}

int main(){
    
    int ret=0;
    
    ret=setup_ib();
    check(ret==0, "Failed to setup IB.");
    
    ret=run_server();
    check(ret==0, "Failed to run server.");
    
error:
    close_ib_connection();
    return ret;
}