all: run

build:
	odin build . --collection:odin8=src -vet-extra -strict-style

run:
	odin build . --collection:odin8=src -vet-extra -strict-style && ./odin8