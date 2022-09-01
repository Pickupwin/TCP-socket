#include <pcap.h>
#include <time.h>
#include <stdlib.h>
#include <stdio.h>

void getPacket(u_char *arg, const struct pcap_pkthdr *pkthdr, const u_char *packet){
    unsigned int *id=(unsigned int *)arg;
    printf("id: %u\n", ++(*id));
    printf("Packet length: %u\n", pkthdr->len);
    printf("Number of bytes: %u\n", pkthdr->caplen);
    printf("Received time: %s\n", ctime((const time_t *)&pkthdr->ts.tv_sec));
    
    for(int i=0;i<pkthdr->caplen;++i){
        printf(" %02x", packet[i]);
        if((i&15)==15)  printf("\n");
    }
    puts("\n");
}

char errBuf[PCAP_ERRBUF_SIZE];

struct bpf_program filter;

int main(){
    
    pcap_t *dev=pcap_open_live("eth0", 65535, 0, 10, errBuf);
    if(!dev){
        printf("error: pcap_open_live():%s\n", errBuf);
        exit(1);
    }
    
    pcap_compile(dev, &filter, "tcp port 2345", 1, 0);
    pcap_setfilter(dev, &filter);
    
    unsigned int id=0u;
    pcap_loop(dev, 10, getPacket, (u_char *)&id);
    pcap_close(dev);
    return 0;
}