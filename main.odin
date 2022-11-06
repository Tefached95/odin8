package main

import "core:os"
import "core:fmt"

import "odin8:screen"
import "odin8:memory"
import "odin8:interpreter"
import "odin8:instruction"

FILENAME :: "./programs/maze.ch8"

main :: proc() {
	file, success := os.read_entire_file_from_filename(FILENAME)

	if success == false {
		panic(fmt.aprintf("Failed reading from %s.", FILENAME))
	}

	scr := screen.make_screen(64, 32)
	defer free(scr)

	mem := memory.make_memory()
	defer free(mem)

	// fmt.printf("%#x >> 4 = %d", 0x14, 0x14 >> 4)

	memory.load_program_into_memory(mem, file)
	interpreter.start_run(mem, scr)
}
