package cpu

import "core:fmt"
import rnd "core:math/rand"
import "core:time"

import instruction "odin8:instruction"
import interpreter "odin8:interpreter"
import memory "odin8:memory"
import screen "odin8:screen"

step :: proc(
    itp: ^interpreter.Interpreter,
    mem: ^memory.Memory,
    scr: ^screen.Screen($W, $H),
) {
    instr := interpreter.get_current_instruction(itp, mem)

    switch instr.most_significant_byte {
    case 0x0:
        switch instr.kk_byte {
        case 0xEE:
            return_from_subroutine(itp, mem)
            return
        case 0xE0:
            screen.clear_screen(scr)
        case:
            sysaddr(itp)
        }
    case 0x1:
        itp.program_counter = instr.address
        return
    case 0x2:
        call_subroutine(itp, mem, instr.address)
        return
    case 0x3:
        skip_check_equality(
            itp,
            mem,
            instr.x,
            instr.kk_byte,
            interpreter.Equality.Eq,
        )
    case 0x4:
        skip_check_equality(
            itp,
            mem,
            instr.x,
            instr.kk_byte,
            interpreter.Equality.Neq,
        )
    case 0x5:
        jump_if_registers_are_equal(
            itp,
            mem,
            instr.x,
            instr.y,
            interpreter.Equality.Eq,
        )
    case 0x6:
        set_register_to_value(mem, instr.x, instr.kk_byte)
    case 0x7:
        increment_register_by_value(mem, instr.x, instr.kk_byte)
    case 0x8:
        switch instr.nibble {
        case 0x0:
            store_value_from_vy_into_vx(mem, instr.x, instr.y)
        case 0x1 ..= 0x3:
            do_bitwise_ops(
                mem,
                instr.x,
                instr.y,
                interpreter.Bitwise_Op(instr.nibble),
            )
        case 0x4:
            add_registers(mem, instr.x, instr.y)
        case 0x5:
            sub_registers(
                mem,
                instr.x,
                instr.y,
                interpreter.Sub_Reversal.Standard,
            )
        case 0x6:
            shift_register(
                mem,
                instr.x,
                instr.y,
                interpreter.Shift_Direction.Right,
            )
        case 0x7:
            sub_registers(
                mem,
                instr.x,
                instr.y,
                interpreter.Sub_Reversal.Reversed,
            )
        case 0xE:
            shift_register(
                mem,
                instr.x,
                instr.y,
                interpreter.Shift_Direction.Left,
            )
        }
    case 0x9:
        jump_if_registers_are_equal(
            itp,
            mem,
            instr.x,
            instr.y,
            interpreter.Equality.Neq,
        )
    case 0xA:
        set_register_i_to_address(mem, instr.address)
    case 0xB:
        jump_to_v0_address(itp, mem, instr.address)
        return
    case 0xC:
        set_register_to_random_byte_anded(mem, instr.x, instr.kk_byte)
    case 0xD:
        draw(scr, mem, instr.x, instr.y, instr.nibble)
    case 0xE:
        panic("Not implemented")
    case 0xF:
        switch instr.kk_byte {
        case 0x1E:
            increment_i_by_vx(mem, instr.x)
        case 0x55:
            spread_registers_into_memory(mem, instr.x)
        case 0x65:
            load_from_memory_into_registers(mem, instr.x)
        case:
            panic(fmt.aprintf("Unsupported argument %X", instr.kk_byte))
        }
    case:
        panic(
            fmt.aprintf(
                "Unsupported instruction %s",
                instruction.debug_print(instr),
            ),
        )
    }

    interpreter.increment_program_counter(itp)
}

sysaddr :: proc(itp: ^interpreter.Interpreter) {
    return
}

call_subroutine :: proc(
    itp: ^interpreter.Interpreter,
    mem: ^memory.Memory,
    address: u16,
) {
    mem.program_stack.pointer += 1
    mem.program_stack.stack[mem.program_stack.pointer] = itp.program_counter

    itp.program_counter = address
}

return_from_subroutine :: proc(
    itp: ^interpreter.Interpreter,
    mem: ^memory.Memory,
) {
    itp.program_counter = mem.program_stack.stack[mem.program_stack.pointer]
    mem.program_stack.pointer -= 1
}

cls :: proc(scr: ^screen.Screen) {
    screen.clear_screen(scr)
}

// ### 3xkk - SE Vx, byte
//
// Skip next instruction if Vx = kk.
//
// The interpreter compares register Vx to kk, and if they are equal, increments the program counter by 2.
//
// ### 4xkk - SNE Vx, byte
//
// Skip next instruction if Vx != kk.
//
// The interpreter compares register Vx to kk, and if they are not equal, increments the program counter by 2.
skip_check_equality :: proc(
    itp: ^interpreter.Interpreter,
    mem: ^memory.Memory,
    register: u8,
    value: byte,
    comp: interpreter.Equality,
) {
    value_x := memory.get_register(mem, register)
    equal := value_x == value

    switch comp {
    case .Eq:
        if equal do interpreter.increment_program_counter(itp)
    case .Neq:
        if !equal do interpreter.increment_program_counter(itp)
    }
}


// ### 5xy0 - SE Vx, Vy
//
// Skip next instruction if Vx = Vy.
//
// The interpreter compares register Vx to register Vy, and if they are equal, increments the program counter by 2.
//
// ### 9xy0 - SNE Vx, Vy
//
// Skip next instruction if Vx != Vy.
//
// The values of Vx and Vy are compared, and if they are not equal, the program counter is increased by 2.
jump_if_registers_are_equal :: proc(
    itp: ^interpreter.Interpreter,
    mem: ^memory.Memory,
    register_x, register_y: byte,
    comp: interpreter.Equality,
) {
    value_x := memory.get_register(mem, register_x)
    value_y := memory.get_register(mem, register_y)

    equal := value_x == value_y

    switch comp {
    case .Eq:
        if equal do interpreter.increment_program_counter(itp)
    case .Neq:
        if !equal do interpreter.increment_program_counter(itp)
    }
}

// ### 6xkk - LD Vx, byte
//
// Set Vx = kk.
//
// The interpreter puts the value kk into register Vx.
set_register_to_value :: proc(
    mem: ^memory.Memory,
    register: byte,
    value: byte,
) {
    memory.set_register(mem, register, value)
}

// ### 7xkk - ADD Vx, byte
//
// Set Vx = Vx + kk.
//
// Adds the value kk to the value of register Vx, then stores the result in Vx. 
increment_register_by_value :: proc(
    mem: ^memory.Memory,
    register: byte,
    value: byte,
) {
    sum := memory.get_register(mem, register) + value
    memory.set_register(mem, register, (sum % 0xFF))
}


// ### 8xy0 - LD Vx, Vy
//
// Set Vx = Vy.
//
// Stores the value of register Vy in register Vx.
store_value_from_vy_into_vx :: proc(
    mem: ^memory.Memory,
    register_x, register_y: byte,
) {
    memory.set_register(mem, register_x, memory.get_register(mem, register_y))
}

// ### 8xy1 - OR Vx, Vy
//
// Set Vx = Vx OR Vy.
//
// Performs a bitwise OR on the values of Vx and Vy, then stores the result in Vx. A bitwise OR compares the corrseponding bits from two values, and if either bit is 1, then the same bit in the result is also 1. Otherwise, it is 0.
//
// ### 8xy2 - AND Vx, Vy
//
// Set Vx = Vx AND Vy.
//
// Performs a bitwise AND on the values of Vx and Vy, then stores the result in Vx. A bitwise AND compares the corrseponding bits from two values, and if both bits are 1, then the same bit in the result is also 1. Otherwise, it is 0.
//
// ### 8xy3 - XOR Vx, Vy
//
// Set Vx = Vx XOR Vy.
//
// Performs a bitwise exclusive OR on the values of Vx and Vy, then stores the result in Vx. An exclusive OR compares the corrseponding bits from two values, and if the bits are not both the same, then the corresponding bit in the result is set to 1. Otherwise, it is 0.
do_bitwise_ops :: proc(
    mem: ^memory.Memory,
    register_x, register_y: byte,
    bitwise_op: interpreter.Bitwise_Op,
) {
    result: byte

    switch bitwise_op {
    case .Or:
        result =
            memory.get_register(mem, register_x) |
            memory.get_register(mem, register_y)
    case .And:
        result =
            memory.get_register(mem, register_x) &
            memory.get_register(mem, register_y)
    case .Xor:
        result =
            memory.get_register(mem, register_x) ~
            memory.get_register(mem, register_y)
    }

    memory.set_register(mem, register_x, byte(result))
}

// ### 8xy4 - ADD Vx, Vy
//
// Set Vx = Vx + Vy, set VF = carry.
//
// The values of Vx and Vy are added together. If the result is greater than 8 bits (i.e., > 255,) VF is set to 1, otherwise 0. Only the lowest 8 bits of the result are kept, and stored in Vx.
add_registers :: proc(mem: ^memory.Memory, register_x, register_y: byte) {
    result :=
        memory.get_register(mem, register_x) +
        memory.get_register(mem, register_y)

    carry := result > 0xFF ? 1 : 0

    memory.set_register(mem, register_x, (result % 0xFF))
    memory.set_register(mem, 0xF, byte(carry))
}

// ### 8xy5 - SUB Vx, Vy
//
// Set Vx = Vx - Vy, set VF = NOT borrow.
//
// If Vx > Vy, then VF is set to 1, otherwise 0. Then Vy is subtracted from Vx, and the results stored in Vx.
sub_registers :: proc(
    mem: ^memory.Memory,
    register_x, register_y: byte,
    reversed: interpreter.Sub_Reversal,
) {
    vx := memory.get_register(mem, register_x)
    vy := memory.get_register(mem, register_y)

    borrow, result: byte

    switch reversed {
    case .Standard:
        borrow = vx > vy ? 1 : 0
        result = vx - vy
    case .Reversed:
        borrow = vx < vy ? 1 : 0
        result = vy - vx
    }

    memory.set_register(mem, 0xF, byte(borrow))
    memory.set_register(mem, register_x, result)
}

// ### 8xy6 - SHR Vx {, Vy}
//
// Set Vx = Vx SHR 1.
//
// If the least-significant bit of Vx is 1, then VF is set to 1, otherwise 0. Then Vx is divided by 2.
//
// ### 8xyE - SHL Vx {, Vy}
//
// Set Vx = Vx SHL 1.
//
// If the most-significant bit of Vx is 1, then VF is set to 1, otherwise to 0. Then Vx is multiplied by 2.
shift_register :: proc(
    mem: ^memory.Memory,
    register_x, register_y: byte,
    shift_direction: interpreter.Shift_Direction,
) {
    vx := memory.get_register(mem, register_x)
    vy := memory.get_register(mem, register_y)

    significant_bit, result: byte

    switch shift_direction {
    case .Right:
        result = vy >> 1
        significant_bit = vx & 0x1
    case .Left:
        result = vy << 1
        significant_bit = vx & 0x80
    }

    memory.set_register(mem, 0xF, significant_bit)
    memory.set_register(mem, register_x, result)
}

// ### Annn - LD I, addr
//
// Set I = nnn.
//
// The value of register I is set to nnn.
set_register_i_to_address :: #force_inline proc(
    mem: ^memory.Memory,
    address: u16,
) {
    mem.register_i = address
}

// ### Bnnn - JP V0, addr
//
// Jump to location nnn + V0.
//
// The program counter is set to nnn plus the value of V0.
jump_to_v0_address :: proc(
    itp: ^interpreter.Interpreter,
    mem: ^memory.Memory,
    address: u16,
) {
    v0_value := memory.get_register(mem, 0x0)
    itp.program_counter = address + u16(v0_value)
}

// ### Cxkk - RND Vx, byte
// 
// Set Vx = random byte AND kk.
// 
// The interpreter generates a random number from 0 to 255, which is then ANDed with the value kk. The results are stored in Vx.
set_register_to_random_byte_anded :: proc(
    mem: ^memory.Memory,
    register_x, kk_byte: byte,
) {
    rand := u8(rnd.uint32() & 0xFF) & kk_byte
    memory.set_register(mem, register_x, rand)
}

// ### Dxyn - DRW Vx, Vy, nibble
// 
// Display n-byte sprite starting at memory location I at (Vx, Vy), set VF = collision.
// 
// The interpreter reads n bytes from memory, starting at the address stored in I. These bytes are then displayed as sprites on screen at coordinates (Vx, Vy).
// Sprites are XORed onto the existing screen. If this causes any pixels to be erased, VF is set to 1, otherwise it is set to 0. If the sprite is positioned so part of it is outside the coordinates of the display, it wraps around to the opposite side of the screen.
draw :: proc(
    scr: ^screen.Screen($W, $H),
    mem: ^memory.Memory,
    register_x, register_y, amount_to_read: byte,
) {
    coordinate_x := memory.get_register(mem, register_x)
    coordinate_y := memory.get_register(mem, register_y)

    data := memory.get_range(mem, mem.register_i, int(amount_to_read))

    collision := screen.draw_sprite(scr, coordinate_x, coordinate_y, data)

    if collision {
        memory.set_register(mem, 0xF, byte(0x1))
    } else {
        memory.set_register(mem, 0xF, byte(0x0))
    }

    screen.draw_screen(scr)
}

// ### Fx1E - ADD I, Vx
//
// Set I = I + Vx.
//
// The values of I and Vx are added, and the results are stored in I.
increment_i_by_vx :: proc(mem: ^memory.Memory, register_x: byte) {
    vx_value := memory.get_register(mem, register_x)
    mem.register_i += u16(vx_value)
}

spread_registers_into_memory :: proc(mem: ^memory.Memory, register_x: byte) {
    here := mem.register_i
    for i in 0 ..= register_x {
        register_value := memory.get_register(mem, i)
        memory.set_at(mem, (here + u16(i)), register_value)
    }

    mem.register_i = mem.register_i + u16(register_x) + interpreter.NEXT_ADDR
}

load_from_memory_into_registers :: proc(
    mem: ^memory.Memory,
    register_x: byte,
) {
    here := mem.register_i
    for i in 0 ..= register_x {
        memory_value := memory.get_at(mem, (here + u16(i)))
        memory.set_register(mem, i, memory_value)
    }

    mem.register_i = mem.register_i + u16(register_x) + interpreter.NEXT_ADDR
}

@(private)
sleep_ms :: proc(ms: time.Duration) {
    time.sleep(time.Millisecond * ms)
}
