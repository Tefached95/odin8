package instruction

import fmt "core:fmt"

Instruction :: struct {
    address:                                      u16,
    most_significant_byte, nibble, kk_byte, x, y: byte,
}

parse_from_bytes :: proc(command, arguments: byte) -> Instruction {
    return(
        Instruction{
            most_significant_byte = command >> 4,
            x = command & 0xF,
            y = arguments >> 4,
            nibble = arguments & 0xF,
            kk_byte = arguments,
            address = be_bytes_to_u16(command, arguments) & 0xFFF,
        } \
    )
}

debug_print :: proc(instr: ^Instruction) -> string {
    return fmt.aprintf(
        "Instruction{{\nmost_significant_byte: %X\nx: %X\ny: %X\nnibble: %X\nkk_byte: %X\naddress: %X\n}}",
        instr.most_significant_byte,
        instr.x,
        instr.y,
        instr.nibble,
        instr.kk_byte,
        instr.address,
    )
}

@(private)
be_bytes_to_u16 :: #force_inline proc(first, second: byte) -> u16 {
    return u16(second) | u16(first) << 8
}
