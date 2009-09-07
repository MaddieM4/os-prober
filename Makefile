CFLAGS := -Os -g -Wall

all: newns

newns: newns.c
	$(CC) $(CFLAGS) $^ -o $@

clean:
	rm -f newns
