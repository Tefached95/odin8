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

Instruction_Cache :: map[u16]instruction.Instruction

Interpreter :: struct {
    program_counter:           u16,
    instruction_cache:         Instruction_Cache,
    // PROCS
    get_current_instruction:   proc(
        itp: ^Interpreter,
        mem: ^memory.Memory,
    ) -> ^instruction.Instruction,
    increment_program_counter: proc(itp: ^Interpreter),
}

make_interpreter :: proc(mem: ^memory.Memory) -> ^Interpreter {
    cache := make(Instruction_Cache, mem.program_length)
    populate_instruction_cache(mem, &cache)

    itp := new_clone(
        Interpreter{
            program_counter = memory.MEMORY_START,
            instruction_cache = cache,
            get_current_instruction = get_current_instruction,
            increment_program_counter = increment_program_counter,
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

    cache_key := instruction.be_bytes_to_u16(command_byte, argument_byte)

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


populate_instruction_cache :: proc(
    mem: ^memory.Memory,
    cache: ^Instruction_Cache,
) {
    for i := 0; i < mem.program_length; i += NEXT_ADDR {
        command_byte := memory.get_at(mem, (u16(i) + memory.MEMORY_START))
        argument_byte := memory.get_at(
            mem,
            (u16(i) + memory.MEMORY_START) + NEXT_ADDR,
        )

        cache_key := instruction.be_bytes_to_u16(command_byte, argument_byte)

        instr := instruction.parse_from_bytes(command_byte, argument_byte)
        (cache^)[cache_key] = instr
    }
}

increment_program_counter :: proc(itp: ^Interpreter) {
    itp.program_counter += STEP_SIZE
}
