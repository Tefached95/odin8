package memory

FONT_START :: 0x50
FONT_SIZE :: 0x5
MEMORY_START :: 0x200
MEMORY_END :: 0xFFF

Memory :: struct {
    ram:                      [4096]byte,
    registers:                [16]byte,
    register_i:               u16,
    program_length:           int,
    subroutine_stack:         [16]u16,
    subroutine_pointer:       u16,
    delay_timer:              u8,
    sound_timer:              u8,
    // PROCS
    load_font_data:           proc(mem: ^Memory),
    load_program_into_memory: proc(mem: ^Memory, program: []byte),
    get_at:                   proc(mem: ^Memory, addr: u16) -> byte,
    set_at:                   proc(mem: ^Memory, addr: u16, value: byte),
    get_range:                proc(
        mem: ^Memory,
        start: u16,
        length: int,
    ) -> []byte,
    set_register:             proc(
        program_memory: ^Memory,
        register, value: byte,
    ),
    get_register:             proc(
        program_memory: ^Memory,
        register: byte,
    ) -> byte,
    set_i_to_font_address:    proc(mem: ^Memory, register: byte),
}

make_memory :: proc() -> ^Memory {
    return new_clone(
        Memory{
            ram = [4096]byte{},
            registers = [16]byte{},
            register_i = 0x00,
            program_length = 0,
            subroutine_stack = [16]u16{},
            subroutine_pointer = 0x0,
            delay_timer = 0x0,
            sound_timer = 0x0,
            load_program_into_memory = load_program_into_memory,
            load_font_data = load_font_data,
            get_at = get_at,
            set_at = set_at,
            get_range = get_range,
            set_register = set_register,
            get_register = get_register,
            set_i_to_font_address = set_i_to_font_address,
        },
    )
}

load_font_data :: proc(mem: ^Memory) {
    font_set := []u8{
        0xF0,
        0x90,
        0x90,
        0x90,
        0xF0,
        0x20,
        0x60,
        0x20,
        0x20,
        0x70,
        0xF0,
        0x10,
        0xF0,
        0x80,
        0xF0,
        0xF0,
        0x10,
        0xF0,
        0x10,
        0xF0,
        0x90,
        0x90,
        0xF0,
        0x10,
        0x10,
        0xF0,
        0x80,
        0xF0,
        0x10,
        0xF0,
        0xF0,
        0x80,
        0xF0,
        0x90,
        0xF0,
        0xF0,
        0x10,
        0x20,
        0x40,
        0x40,
        0xF0,
        0x90,
        0xF0,
        0x90,
        0xF0,
        0xF0,
        0x90,
        0xF0,
        0x10,
        0xF0,
        0xF0,
        0x90,
        0xF0,
        0x90,
        0x90,
        0xE0,
        0x90,
        0xE0,
        0x90,
        0xE0,
        0xF0,
        0x80,
        0x80,
        0x80,
        0xF0,
        0xE0,
        0x90,
        0x90,
        0x90,
        0xE0,
        0xF0,
        0x80,
        0xF0,
        0x80,
        0xF0,
        0xF0,
        0x80,
        0xF0,
        0x80,
        0x80,
    }

    font_offset: u8 = FONT_START

    for element in font_set {
        mem.ram[font_offset & 0xFF] = element
        font_offset += 1
    }
}

load_program_into_memory :: proc(mem: ^Memory, program: []byte) {
    load_font_data(mem)
    for value, index in program {
        mem.ram[index + MEMORY_START] = value
    }

    mem.program_length = len(program)
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

set_register :: proc(program_memory: ^Memory, register, value: byte) {
    program_memory.registers[register] = value
}

get_register :: proc(program_memory: ^Memory, register: byte) -> byte {
    return program_memory.registers[register]
}

set_i_to_font_address :: proc(mem: ^Memory, register: byte) {
    font_address := u16(mem->get_register(register) * FONT_SIZE) + FONT_START
    mem.register_i = font_address & 0xFFF
}
