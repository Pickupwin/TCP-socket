SRC=$(wildcard ./*.c)
AIM=$(patsubst %.c,%,$(SRC))
LIBS=-lpcap
OUT_DIR=../../build

ALL:$(AIM) $(SRC)

$(AIM):%:%.c $(OUT_DIR)
	gcc $^ -o $(OUT_DIR)/$@ $(LIBS)