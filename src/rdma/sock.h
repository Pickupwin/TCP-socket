#include <sys/socket.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <errno.h>

struct sockaddr_in Get_addr(in_addr_t inaddr, in_port_t inport);

int Open_server_socket(const struct sockaddr *addr, int quelen);

ssize_t Recv_n(int fd, char *p, size_t n);
ssize_t Send_n(int fd, const char *p, size_t n);