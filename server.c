#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <errno.h>

const uint16_t PORT=2345;
const unsigned long long FSIZ=17179869184ULL;    //16GB

char Buf[BUFSIZ];
char FileName[33];

int server_fd, client_fd;

struct sockaddr_in Get_addr(in_addr_t inaddr, in_port_t inport){
    struct sockaddr_in ret;
    memset(&ret, 0, sizeof(ret));
    ret.sin_family=AF_INET;
    ret.sin_addr.s_addr=inaddr;
    ret.sin_port=inport;
    return ret;
}

int Open_server_socket(const struct sockaddr *addr, int q){
    int ret;
    if((ret=socket(PF_INET, SOCK_STREAM, 0))<0){
        perror("socket error!");
        exit(1);
    }
    if(bind(ret, addr, sizeof(struct sockaddr))<0){
        perror("bind error!");
        exit(1);
    }
    if(listen(ret, q)<0){
        perror("listen error!");
        exit(1);
    }
    return ret;
}

ssize_t Recv(int fd, void *buf, size_t n){
    ssize_t nrecv;
    while((nrecv=recv(fd, buf, n, 0))<0){
        if(errno!=EINTR)
            return -1;
    }
    return nrecv;
}

ssize_t Send(int fd, const char *p, size_t n){
    size_t nleft=n;
    ssize_t nw;
    const char *bp=p;
    while(nleft>0){
        if((nw=send(fd, p, nleft, 0))<=0){
            if(errno==EINTR)
                nw=0;
            else
                return -1;
        }
        nleft-=nw;
        bp+=nw;
    }
    return n;
}

int Inform_client(int fd, const char *p){
    size_t n=strlen(p);
    if(Send(fd, p, n)!=n)   return 0;
    return 1;
}
void Reject_client(int fd, const char *p){
    Inform_client(fd, p);
    close(fd);
}

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

int main(){
    
    struct sockaddr_in my_addr=Get_addr(INADDR_ANY, htons(PORT));
    
    server_fd=Open_server_socket((struct sockaddr *)&my_addr, 5);
    
    for(int tt=10, len;tt--;){
        struct sockaddr_in remote_addr;
        unsigned int sin_size=sizeof(struct sockaddr_in);
        FILE *pFile;
        if((client_fd=accept(server_fd, (struct sockaddr *)&remote_addr, &sin_size))<0){
            perror("accept error!");
            continue;
        }
        len=Recv(client_fd, Buf, BUFSIZ);
        if(len<=0){
            // error or closed.
            close(client_fd);
            continue;
        }
        else if(len>32){
            Reject_client(client_fd, "File name is too long.\n");
            continue;
        }
        memcpy(FileName, Buf, len);FileName[len]='\0';
        if(!(pFile=fopen(FileName, "wb"))){
            Reject_client(client_fd, "Can't open requested file.\n");
            continue;
        }
        if(!Inform_client(client_fd, "File opened.\n")){
            fclose(pFile);
            close(client_fd);
            continue;
        }
        len=Recv(client_fd, Buf, BUFSIZ);
        if(len<=0){
            // error or closed.
            fclose(pFile);
            close(client_fd);
            continue;
        }
        unsigned long long cksum, flen;
        if(sscanf(Buf, "%llu%llu", &cksum, &flen)!=2){
            fclose(pFile);
            Reject_client(client_fd, "Invalid cksum.\n");
            continue;
        }
        if(flen>FSIZ){
            fclose(pFile);
            Reject_client(client_fd, "File too large.\n");
            continue;
        }
        if(!Inform_client(client_fd, "cksum Received.\n")){
            fclose(pFile);
            close(client_fd);
            continue;
        }
        unsigned long long cflen=0ull;
        while((len=Recv(client_fd, Buf, (cflen-flen>BUFSIZ)?BUFSIZ:(size_t)(cflen-flen)))>0){
            fwrite(Buf, sizeof(char), len, pFile);
            cflen+=len;if(cflen>=flen)  break;
        }
        fclose(pFile);
        unsigned long long rcksum, rflen;
        if(Gen_cksum(FileName, &rcksum, &rflen) && rcksum==cksum && rflen==flen){
            Reject_client(client_fd, "OK");
            printf("OK %llu %llu %s\n", cksum, flen, FileName);
        }
        else{
            sprintf(Buf, "rm %s -rf", FileName);
            system(Buf);
            Reject_client(client_fd, "Failed");
        }
    }
    
    close(server_fd);
    
    return 0;
}