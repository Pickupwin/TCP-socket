LIBS=-libverbs

ADDS=ib.c sock.c sock_setup_ib.c

SRCS=server.c client.c
OBJS=$(patsubst %.c,%,$(SRCS))
OUT_DIR=../../build

all: $(OBJS)

$(OBJS):$(SRCS) $(ADDS) $(OUT_DIR)
	gcc $< $(ADDS) -o $(OUT_DIR)/$@ $(LIBS)
