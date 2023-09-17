package main

import "core:fmt"
import "core:os"

import cpu "odin8:cpu"
import interpreter "odin8:interpreter"
import memory "odin8:memory"
import screen "odin8:screen"

main :: proc() {
    args := os.args
    if (len(args) == 1) {
        fmt.printf("Usage: ./odin8 <path_to_ch8_file>\n")
        return
    }

    program_path := args[1]
    file, ok := os.read_entire_file_from_filename(program_path)

    if ok == false {
        panic(fmt.aprintf("Failed reading from %s.", program_path))
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
