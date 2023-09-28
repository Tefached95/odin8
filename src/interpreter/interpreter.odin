package interpreter

import fmt "core:fmt"
import strings "core:strings"

import instruction "odin8:instruction"
import memory "odin8:memory"

NEXT_ADDR :: 0x1
STEP_SIZE :: 0x2

Equality :: enum {
    Eq,
    Neq,
}
Sub_Reversal :: enum {
    Standard,
    Reversed,
}
Bitwise_Op :: enum byte {
    Or  = 0x1,
    And = 0x2,
    Xor = 0x3,
}
Shift_Direction :: enum {
    Left,
    Right,
}

Interpreter :: struct {
    program_counter:   u16,
    instruction_cache: map[string]instruction.Instruction,
}

make_interpreter :: proc(mem: ^memory.Memory) -> ^Interpreter {
    sb := strings.builder_make()
    defer strings.builder_destroy(&sb)

    cache := make(map[string]instruction.Instruction, mem.program_length)
    populate_instruction_cache(&sb, mem, &cache)

    itp := new_clone(
        Interpreter{
            program_counter = memory.MEMORY_START,
            instruction_cache = cache,
        },
    )

    return itp
}

get_current_instruction :: proc(
    itp: ^Interpreter,
    mem: ^memory.Memory,
) -> ^instruction.Instruction {
    sb := strings.builder_make()
    defer strings.builder_destroy(&sb)

    command_byte := memory.get_at(mem, itp.program_counter)
    argument_byte := memory.get_at(mem, itp.program_counter + NEXT_ADDR)

    cache_key := bytes_to_cache_key(&sb, command_byte, argument_byte)

    instr, ok := &itp.instruction_cache[cache_key]

    if ok == false {
        new_instr := new_clone(
            instruction.parse_from_bytes(command_byte, argument_byte),
        )
        itp.instruction_cache[cache_key] = new_instr^
        return new_instr
    }

    return instr
}

bytes_to_cache_key :: proc(sb: ^strings.Builder, b1, b2: byte) -> string {
    defer strings.builder_reset(sb)

    fmt.sbprintf(sb, "%X%X", b1, b2)

    cache_key, err := strings.clone(strings.to_string(sb^))
    if err != nil {
        panic(fmt.aprintf("Could not clone cache key."))
    }

    return cache_key
}

populate_instruction_cache :: proc(
    sb: ^strings.Builder,
    mem: ^memory.Memory,
    cache: ^map[string]instruction.Instruction,
) {
    for i := 0; i < mem.program_length; i += NEXT_ADDR {
        command_byte := memory.get_at(mem, (u16(i) + memory.MEMORY_START))
        argument_byte := memory.get_at(
            mem,
            (u16(i) + memory.MEMORY_START) + NEXT_ADDR,
        )

        cache_key := bytes_to_cache_key(sb, command_byte, argument_byte)

        instr := instruction.parse_from_bytes(command_byte, argument_byte)
        (cache^)[cache_key] = instr
    }
}

increment_program_counter :: proc(itp: ^Interpreter) {
    itp.program_counter += STEP_SIZE
}
