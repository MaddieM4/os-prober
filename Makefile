CFLAGS := -Os -g -Wall

all: newns

newns: newns.c
	$(CC) $(CFLAGS) $(LDFLAGS) $^ -o $@

check: newns
	./os-prober
	./os-prober | grep ':'
	./linux-boot-prover
	./linux-boot-prover | grep ':'

clean:
	rm -f newns
