package main

import "core:fmt"
import "core:os"

import "odin8:cpu"
import "odin8:instruction"
import "odin8:interpreter"
import "odin8:memory"
import "odin8:screen"

FILENAME :: "./programs/maze.ch8"

main :: proc() {
    file, ok := os.read_entire_file_from_filename(FILENAME)

    if ok == false {
        panic(fmt.aprintf("Failed reading from %s.", FILENAME))
    }

    scr := screen.make_screen(64, 32)
    defer free(scr)

    mem := memory.make_memory()
    memory.load_program_into_memory(mem, file)
    defer free(mem)

    itp := interpreter.make_interpreter(mem)
    defer free(itp)

    for {
        cpu.step(itp, mem, scr)
    }
}
