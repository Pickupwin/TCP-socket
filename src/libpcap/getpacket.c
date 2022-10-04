#include <pcap.h>
#include <time.h>
#include <stdlib.h>
#include <stdio.h>

FILE* pFile=NULL;

void getPacket(u_char *arg, const struct pcap_pkthdr *pkthdr, const u_char *packet){
    unsigned int *id=(unsigned int *)arg;
    fprintf(pFile?pFile:stdout, "id: %u\n", ++(*id));
    fprintf(pFile?pFile:stdout, "Packet length: %u\n", pkthdr->len);
    fprintf(pFile?pFile:stdout, "Number of bytes: %u\n", pkthdr->caplen);
    fprintf(pFile?pFile:stdout, "Received time: %s\n", ctime((const time_t *)&pkthdr->ts.tv_sec));
    
    for(int i=0;i<pkthdr->caplen;++i){
        fprintf(pFile?pFile:stdout, " %02x", packet[i]);
        if((i&15)==15)  fprintf(pFile?pFile:stdout, "\n");
    }
    fputs("\n", pFile?pFile:stdout);
}

char errBuf[PCAP_ERRBUF_SIZE];

struct bpf_program filter;

int main(){
    
    pcap_t *dev=pcap_open_live("enp94s0f1", 65535, 0, 10, errBuf);
    if(!dev){
        printf("error: pcap_open_live():%s\n", errBuf);
        exit(1);
    }
    
    pcap_compile(dev, &filter, "", 1, 0);
    pcap_setfilter(dev, &filter);
    
    // pFile=fopen("packet.log", "w");
    pFile=NULL;
    unsigned int id=0u;
    pcap_loop(dev, 10, getPacket, (u_char *)&id);
    pcap_close(dev);
    if(pFile)   fclose(pFile);
    return 0;
}