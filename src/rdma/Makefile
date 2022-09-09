LIBS=-libverbs

ADDS=ib.c sock.c sock_setup_ib.c

SRCS=server.c client.c
OBJS=$(patsubst %.c,%,$(SRCS))
OUT_DIR=../../build

all: $(OBJS) $(ADDS) $(OUT_DIR)

$(OBJS):%:%.c
	gcc $^ $(ADDS) -o $(OUT_DIR)/$@ $(LIBS)
