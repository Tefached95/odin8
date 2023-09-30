all: build

build:
	odin build . --collection:odin8=src -strict-style -o:speed