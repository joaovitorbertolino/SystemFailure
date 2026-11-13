.PHONY: all run clean

all: build/teste.nes

build/main.o: src/main.s
	ca65 src/main.s -o build/main.o

build/teste.nes: build/main.o cfg/nes.cfg
	ld65 -C cfg/nes.cfg build/main.o -o build/SystemFailure.nes

run: build/teste.nes
	mesen build/SystemFailure.nes

clean:
	rm -f build/*
