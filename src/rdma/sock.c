#include "sock.h"

struct sockaddr_in Get_addr(in_addr_t inaddr, in_port_t inport){
    struct sockaddr_in ret;
    memset(&ret, 0, sizeof(ret));
    ret.sin_family=AF_INET;
    ret.sin_addr.s_addr=inaddr;
    ret.sin_port=inport;
    return ret;
}

int Open_server_socket(const struct sockaddr *addr, int quelen){
    int ret;
    if((ret=socket(PF_INET, SOCK_STREAM, 0))<0){
        perror("socket error!");
        return -1;
    }
    if(bind(ret, addr, sizeof(struct sockaddr))<0){
        perror("bind error!");
        return -1;
    }
    if(listen(ret, quelen)<0){
        perror("listen error!");
        return -1;
    }
    return ret;
}

ssize_t Recv_n(int fd, char *p, size_t n){
    size_t nleft=n;
    ssize_t nr;
    char *bp=p;
    while(nleft>0u){
        if((nr=recv(fd, p, n, 0))<0){
            if(errno!=EINTR)
                return -1;
            nr=0;
        }
        nleft-=nr;
        bp+=nr;
    }
    return n;
}

ssize_t Send_n(int fd, const char *p, size_t n){
    size_t nleft=n;
    ssize_t nw;
    const char *bp=p;
    while(nleft>0u){
        if((nw=send(fd, p, nleft, 0))<=0){
            if(errno!=EINTR)
                return -1;
            nw=0;
        }
        nleft-=nw;
        bp+=nw;
    }
    return n;
}

