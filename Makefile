.PHONY: build_dirs
CFLAGS := -Os -g -Wall

# NixOS uses the $out variable to indicate build output location
ifeq "$(out)" ""
	export LIB_DIR := /usr/lib/os-prober
	export BIN_DIR := /usr/bin/os-prober
else
	export LIB_DIR := $(out)/lib
	export BIN_DIR := $(out)/bin
endif

all: build/bin/os-prober build/bin/linux-boot-prober build/lib/newns

build_dirs:
	mkdir -p build/bin build/lib

build/lib/newns: build_dirs src/newns.c
	$(CC) $(CFLAGS) $(LDFLAGS) src/newns.c -o build/lib/newns

build/bin/os-prober: build/lib/common.sh src/os-prober
	./do-build-replace < src/os-prober > build/bin/os-prober
	chmod +x build/bin/os-prober

build/bin/linux-boot-prober: build/lib/common.sh src/linux-boot-prober
	./do-build-replace < src/linux-boot-prober > build/bin/linux-boot-prober
	chmod +x build/bin/linux-boot-prober

build/lib/common.sh: build_dirs src/common.sh
	./do-build-replace < src/common.sh > build/lib/common.sh

check: build/lib/newns
	./build/bin/os-prober
	./build/bin/os-prober | grep ':'
	./build/bin/linux-boot-prover
	./build/bin/linux-boot-prover | grep ':'

install: all
	mkdir -p $(LIB_DIR) $(BIN_DIR)
	cp -r build/lib/* $(LIB_DIR)
	cp -a build/bin/* $(BIN_DIR)

clean:
	rm -f newns
