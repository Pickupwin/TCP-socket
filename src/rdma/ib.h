
#include <inttypes.h>
#include <endian.h>
#include <byteswap.h>
#include <infiniband/verbs.h>
#include <arpa/inet.h>

#include "debug.h"

#define IB_MTU IBV_MTU_4096
#define IB_PORT 1
#define IB_SL 0


#if __BYTE_ORDER == __LITTLE_ENDIAN
static inline uint64_t htonll (uint64_t x) {return bswap_64(x); }
static inline uint64_t ntohll (uint64_t x) {return bswap_64(x); }
#elif __BYTE_ORDER == __BIG_ENDIAN
static inline uint64_t htonll (uint64_t x) {return x; }
static inline uint64_t ntohll (uint64_t x) {return x; }
#else
#error __BYTE_ORDER is neither __LITTLE_ENDIAN nor __BIG_ENDIAN
#endif

enum MsgType{
    MSG_REGULAR=0,
    MSG_SUCCESS,
    MSG_FAILED,
};

int modify_qp_to_rts(struct ibv_qp *qp, uint32_t qp_num, uint16_t lid);

int post_send(uint32_t req_size, uint32_t lkey, uint64_t wr_id, uint32_t imm_data, struct ibv_qp *qp, char *buf);

int post_recv(uint32_t req_size, uint32_t lkey, uint64_t wr_id, struct ibv_qp *qp, char *buf);