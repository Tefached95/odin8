all: run

build:
	odin build . --collection:odin8=src -vet-extra -warnings-as-errors -strict-style

run:
	odin build . --collection:odin8=src -vet-extra -warnings-as-errors -strict-style && ./odin8