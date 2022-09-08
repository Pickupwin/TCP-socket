SRC=$(wildcard ./*.c)
AIM=$(patsubst %.c,%,$(SRC))
OUT_DIR=../../build

ALL:$(AIM)

$(AIM):$(SRC) $(OUT_DIR)
	gcc $< -o $(OUT_DIR)/$@