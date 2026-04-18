package odin8

import "core:fmt"
import "core:mem"
import "core:os"

import cpu "src/cpu"
import interpreter "src/interpreter"
import memory "src/memory"
import screen "src/screen"

main :: proc() {
    args := os.args
    if (len(args) == 1) {
        fmt.printf("Usage: ./odin8 <path_to_ch8_file>\n")
        return
    }

    tracking_allocator: mem.Tracking_Allocator
    mem.tracking_allocator_init(&tracking_allocator, context.allocator)
    defer mem.tracking_allocator_destroy(&tracking_allocator)
    context.allocator = mem.tracking_allocator(&tracking_allocator)

    program_path := args[1]
    file, err := os.read_entire_file_from_path(program_path, context.allocator)

    if err != nil {
        panic(fmt.aprintf("Failed reading from %s, error: %s", program_path, err))
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

    for _, leak in tracking_allocator.allocation_map {
        fmt.printf("%v leaked %m\n", leak.location, leak.size)
    }
}
