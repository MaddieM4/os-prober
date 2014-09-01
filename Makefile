CFLAGS := -Os -g -Wall

all: build/bin/os-prober build/bin/linux-boot-prober build/lib/newns

build/lib/newns: newns.c build/lib
	$(CC) $(CFLAGS) $(LDFLAGS) $^ -o "$@"

build/bin:
	mkdir -p build/bin

build/lib:
	mkdir -p build/lib

build/bin/os-prober: build/bin src/os-prober
	./do-build-replace < src/os-prober > build/bin/os-prober

build/bin/linux-boot-prober: build/bin src/linux-boot-prober
	./do-build-replace < src/linux-boot-prober > build/bin/linux-boot-prober

build/lib/common.sh: build/lib src/common.sh
	./do-build-replace < src/common.sh > build/lib/common.sh

check: build/lib/newns
	./build/lib/os-prober
	./build/lib/os-prober | grep ':'
	./build/lib/linux-boot-prover
	./build/lib/linux-boot-prover | grep ':'

clean:
	rm -f newns
