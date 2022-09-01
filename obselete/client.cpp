#include <cstdio>
#include <cstring>
#include <cstdlib>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <unistd.h>

const int BUFSIZE=1024;

char Buf[BUFSIZE];

int client_fd;

struct sockaddr_in remote_addr;

int main(int argc, char *argv[]){
    
    if(argc!=3){
        printf("arg error!\n");
        return -1;
    }
    
    memset(&remote_addr, 0, sizeof(remote_addr));
    
    remote_addr.sin_family=AF_INET;
    remote_addr.sin_addr.s_addr=inet_addr("127.0.0.1");
    remote_addr.sin_port=htons(2345);
    
    if((client_fd=socket(PF_INET, SOCK_STREAM, 0))<0){
        perror("socker failed!");
        return -1;
    }
    
    if(connect(client_fd, (struct sockaddr *)&remote_addr, sizeof(struct sockaddr))<0){
        perror("connect failed!");
        return -1;
    }
    
    
    printf("connected to server.\n");
    
    
    
    int len=recv(client_fd, Buf, BUFSIZE, 0);
    Buf[len]='\0';printf("%s\n", Buf);
    len=send(client_fd, argv[2], strlen(argv[2]), 0);
    
    len=recv(client_fd, Buf, BUFSIZE, 0);
    
    sprintf(Buf, "cksum %s > tmp.txt", argv[1]);
    system(Buf);
    FILE* pFile=fopen("tmp.txt", "rb");
    if((len=fread(Buf, sizeof(char), BUFSIZE, pFile))>0){
        len=send(client_fd, Buf, len, 0);
    }
    else{
        printf("cksum failed!");
        return -1;
    }
    fclose(pFile);
    
    len=recv(client_fd, Buf, BUFSIZE, 0);
    
    pFile=fopen(argv[1], "rb");
    if(!pFile){
        perror("fopen failed!");
        return -1;
    }
    while((len=fread(Buf, sizeof(char), BUFSIZE, pFile))>0){
        len=send(client_fd, Buf, len, 0);
    }
    
    fclose(pFile);
    
    // for(int i=0;i<10;++i){
    //     for(int j=0;j<10;++j)   Buf[j]='A'+i;
    //     len=send(client_fd, Buf, 10, 0);
    // }
    
    close(client_fd);
    
    return 0;
}