SHELL := /bin/bash

.PHONY: all prepare build test test-bios clean

all: build

prepare:
	./prepare.sh

build:
	./build.sh

test:
	./test-qemu.sh --uefi

test-bios:
	./test-qemu.sh --bios

clean:
	rm -rf build
