package memory

MEMORY_START :: 0x200
MEMORY_END :: 0xFFF

Program_Stack :: struct {
    stack:   [16]u16,
    pointer: u16,
}

Memory :: struct {
    ram:                [4096]byte,
    registers:          [16]byte,
    register_i:         u16,
    program_length:     int,
    subroutine_stack:   [16]u16,
    subroutine_pointer: u16,
}

make_memory :: proc() -> ^Memory {
    return new_clone(
        Memory{
            ram = [4096]byte{},
            registers = [16]byte{},
            register_i = 0x00,
            program_length = 0,
            subroutine_stack = [16]u16{},
            subroutine_pointer = 0x0000,
        },
    )
}

load_font_data :: proc(mem: ^Memory) {

}

load_program_into_memory :: proc(program_memory: ^Memory, program: []byte) {
    for value, index in program {
        program_memory.ram[index + MEMORY_START] = value
    }

    program_memory.program_length = len(program)
}

get_at :: proc(mem: ^Memory, addr: u16) -> byte {
    return mem.ram[int(addr)]
}

set_at :: proc(mem: ^Memory, addr: u16, value: byte) {
    mem.ram[int(addr)] = value
}

get_range :: proc(mem: ^Memory, start: u16, length: int) -> []byte {
    // TODO: add bounds checking
    return mem.ram[start:(int(start) + length)]
}

set_register :: #force_inline proc(
    program_memory: ^Memory,
    register, value: byte,
) {
    program_memory.registers[register] = value
}

get_register :: #force_inline proc(
    program_memory: ^Memory,
    register: byte,
) -> byte {
    return program_memory.registers[register]
}
