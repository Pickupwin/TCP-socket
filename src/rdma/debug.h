#define log_err(M, ...) fprintf(stderr, "ERR %s:%d:%s "M"\n", __FILE__, __LINE__, __func__, ##__VA_ARGS__)
#define check(C, M, ...) if(!(C)){log_err(M, ##__VA_ARGS__);goto error;}
