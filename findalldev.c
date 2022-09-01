
#include <pcap.h>
#include <time.h>
#include <stdlib.h>
#include <stdio.h>

char errBuf[PCAP_ERRBUF_SIZE];

int main(){
    pcap_if_t *allDev;
    pcap_findalldevs(&allDev, errBuf);
    for(pcap_if_t *p=allDev;p;p=p->next){
        printf("@:%s\n", p->name);
    }
    pcap_freealldevs(allDev);
    return 0;
}