#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <errno.h>

const uint16_t PORT=2345;
#define SERVER_IP "127.0.0.1"

char Buf[BUFSIZ];

int client_fd;

struct sockaddr_in Get_addr(in_addr_t inaddr, in_port_t inport){
    struct sockaddr_in ret;
    memset(&ret, 0, sizeof(ret));
    ret.sin_family=AF_INET;
    ret.sin_addr.s_addr=inaddr;
    ret.sin_port=inport;
    return ret;
}

void Send(int fd, const char *p, size_t n){
    size_t nleft=n;
    ssize_t nw;
    const char *bp=p;
    while(nleft>0){
        if((nw=send(fd, p, nleft, 0))<=0){
            if(errno==EINTR)
                nw=0;
            else{
                printf("send error!\n");
                exit(1);
            }
        }
        nleft-=nw;
        bp+=nw;
    }
}

ssize_t Recv(int fd, void *buf, size_t n){
    ssize_t nrecv;
    while((nrecv=recv(fd, buf, n, 0))<0){
        if(errno!=EINTR)
            exit(1);
    }
    return nrecv;
}

int Send_cksum(const char *f){
    sprintf(Buf, "cksum %s > tmp.txt", f);
    system(Buf);
    FILE *pFile=fopen("tmp.txt", "rb");
    if(!pFile)
        return 0;
    int len=fread(Buf, sizeof(char), BUFSIZ, pFile);
    if(len<=0)
        return 0;
    fclose(pFile);
    system("rm tmp.txt -rf");
    Send(client_fd, Buf, len);
    return 1;
}


int main(int argc, char *argv[]){
    
    if(argc!=3){
        printf("arg error!\n");
        return 1;
    }
    
    FILE *pFile=fopen(argv[1], "rb");
    if(!pFile){
        perror("fopen failed!");
        return -1;
    }
    
    struct sockaddr_in remote_addr=Get_addr(inet_addr(SERVER_IP), htons(PORT));
    
    if((client_fd=socket(PF_INET, SOCK_STREAM, 0))<0){
        perror("socker failed!");
        return 1;
    }
    
    if(connect(client_fd, (struct sockaddr *)&remote_addr, sizeof(struct sockaddr))<0){
        perror("connect failed!");
        return 1;
    }
    
    printf("connected to server.\n");
    
    int len;
    
    Send(client_fd, argv[2], strlen(argv[2]));
    
    len=Recv(client_fd, Buf, BUFSIZ);Buf[len]='\0';printf("%s\n", Buf);
    if(strcmp(Buf, "File opened.\n")){
        printf("Target File error!\n");
        close(client_fd);
        return 1;
    }
    
    if(!Send_cksum(argv[1])){
        printf("cksum error!\n");
        close(client_fd);
        return 1;
    }
    
    len=Recv(client_fd, Buf, BUFSIZ);Buf[len]='\0';printf("%s\n", Buf);
    if(strcmp(Buf, "cksum Received.\n")){
        printf("cksum error!\n");
        close(client_fd);
        return 1;
    }
    
    while((len=fread(Buf, sizeof(char), BUFSIZ, pFile))>0){
        Send(client_fd, Buf, len);
    }
    
    fclose(pFile);
    
    close(client_fd);
    
    return 0;
}