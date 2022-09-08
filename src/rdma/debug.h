#include <stdio.h>


#define verbose_errno() (errno==0?"None":strerror(errno))
#define log_err(M, ...) fprintf(stderr, "ERR %s:%d:%s (%s) "M"\n", __FILE__, __LINE__, __func__, verbose_errno(), ##__VA_ARGS__)
#define check(C, M, ...) if(!(C)){log_err(M, ##__VA_ARGS__);errno=0;goto error;}
