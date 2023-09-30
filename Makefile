all: run

build:
	odin build . --collection:odin8=src -strict-style

run:
	odin build . --collection:odin8=src -strict-style && ./odin8