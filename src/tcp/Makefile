SRC=$(wildcard ./*.c)
AIM=$(patsubst %.c,%,$(SRC))
OUT_DIR=../../build

ALL:$(AIM) $(SRC) $(OUT_DIR)

$(AIM):%:%.c
	gcc $^ -o $(OUT_DIR)/$@