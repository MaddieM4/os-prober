CFLAGS := -Os -g -Wall

all: newns

newns: newns.c
	$(CC) $(CFLAGS) $(LDFLAGS) $^ -o $@

clean:
	rm -f newns
