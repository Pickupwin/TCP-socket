#include <cstdio>
#include <cstring>
#include <cstdlib>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <unistd.h>

const int BUFSIZE=1024;

char Buf[BUFSIZE], Name[BUFSIZE>>1];

int server_fd, client_fd;

struct sockaddr_in my_addr, remote_addr;

int main(){
    
    memset(&my_addr, 0, sizeof(my_addr));
    
    my_addr.sin_family=AF_INET;
    my_addr.sin_addr.s_addr=INADDR_ANY;
    my_addr.sin_port=htons(2345);
    
    if((server_fd=socket(PF_INET, SOCK_STREAM, 0))<0){
        perror("socker failed!");
        return -1;
    }
    
    if(bind(server_fd, (struct sockaddr *)&my_addr, sizeof(struct sockaddr))<0){
        perror("bind failed!");
        return -1;
    }
    
    if(listen(server_fd, 5)<0){
        perror("listen failed!");
        return -1;
    }
    
    int T=10;
    while(T--){
        unsigned int sin_size=sizeof(struct sockaddr_in);
        if((client_fd=accept(server_fd, (struct sockaddr *)&remote_addr, &sin_size))<0){
            perror("accept failed!");
            return -1;
        }
        printf("accept %s\n", inet_ntoa(remote_addr.sin_addr));
        int len=send(client_fd, "Hello\n", 6, 0);
        len=recv(client_fd, Name, BUFSIZE>>1, 0);
        FILE *pFile=fopen(Name, "wb");
        if(!pFile){
            perror("fopen failed!");
            return -1;
        }
        len=send(client_fd, "File ACK\n", 9, 0);
        if((len=recv(client_fd, Buf, BUFSIZE, 0))>0){
            printf("%s\n", Buf);
        }
        len=send(client_fd, "cksum ACK\n", 10, 0);
        long long sum;int ll;
        sscanf(Buf, "%lld %d", &sum, &ll);
        while((len=recv(client_fd, Buf, BUFSIZE, 0))>0){
            fwrite(Buf, sizeof(char), len, pFile);
        }
        fclose(pFile);
        sprintf(Buf, "cksum %s > tmp.txt", Name);
        system(Buf);
        pFile=fopen("tmp.txt", "rb");
        long long rsum;int rlen;
        fscanf(pFile, "%lld %d", &rsum, &rlen);
        printf("%lld %d\n", rsum, rlen);
        fclose(pFile);
        if(rsum==sum && rlen==ll){
            printf("OK\n");
        }
        else{
            printf("cksum error!");
        }
        close(client_fd);
    }
    
    close(server_fd);
    
    return 0;
}