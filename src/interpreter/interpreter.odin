package interpreter

import "core:fmt"
import "core:time"
import rnd "core:math/rand"

import "odin8:screen"
import "odin8:memory"
import "odin8:instruction"

NEXT_ADDR :: 0x1
STEP_SIZE :: 0x2

Equality :: enum {
    Eq,
    Neq
}
Sub_Reversal :: enum {
    Standard,
    Reversed
}
Bitwise_Op :: enum byte {
    And = 0x1,
    Or = 0x2,
    Xor = 0x3
}
Shift_Direction :: enum {
    Left,
    Right
}

Interpreter :: struct {
    program_counter: u16
}

start_run :: proc(mem: ^memory.Memory, scr: ^screen.Screen($W, $H)) {
    instr: instruction.Instruction;

    itp := Interpreter{program_counter = 0x200}
    eof := false

    for eof != true {
        assert(itp.program_counter % 2 == 0, fmt.aprintf("Program counter stopped on an odd address: %X\n", itp.program_counter))
        
        sleep_ms(16)

        command_byte  := memory.get_at(mem, itp.program_counter)
        argument_byte := memory.get_at(mem, itp.program_counter + NEXT_ADDR)

        instr = instruction.parse_from_bytes(command_byte, argument_byte)

        switch instr.most_significant_byte {
            case 0x0:
                if (argument_byte == 0xEE) {
                    return_from_subroutine(&itp, mem)
                    continue
                }
    
                if (argument_byte == 0xE0) {
                    screen.clear_screen(scr)
                }
                
                continue
            case 0x1:
                itp.program_counter = instr.address
                continue
            case 0x2:
                call_subroutine(&itp, mem, instr.address)
                continue
            case 0x3:
                jump_if_equals(&itp, mem, instr.x, instr.kk_byte, Equality.Eq)
            case 0x4:
                jump_if_equals(&itp, mem, instr.x, instr.kk_byte, Equality.Neq)
            case 0x5:
                jump_if_registers_are_equal(&itp, mem, instr.x, instr.y)
            case 0x6:
                set_register_to_value(mem, instr.x, instr.kk_byte)
            case 0x7:
                increment_register_by_value(mem, instr.x, instr.kk_byte)
            case 0x8:
                switch instr.nibble {
                    case 0x0:
                        store_value_from_vy_into_vx(mem, instr.x, instr.y)
                    case 0x1..=0x3:
                        do_bitwise_ops(mem, instr.x, instr.y, Bitwise_Op(instr.nibble))
                    case 0x4:
                        add_registers(mem, instr.x, instr.y)
                    case 0x5:
                        sub_registers(mem, instr.x, instr.y, Sub_Reversal.Standard)
                    case 0x6:
                        shift_register(mem, instr.x, Shift_Direction.Right)
                    case 0x7:
                        sub_registers(mem, instr.x, instr.y, Sub_Reversal.Reversed)
                    case 0xE:
                        shift_register(mem, instr.x, Shift_Direction.Left)
                }
            case 0x9:
                jump_if_registers_are_equal(&itp, mem, instr.x, instr.y, Equality.Neq)
            case 0xA:
                set_register_i_to_address(mem, instr.address)
            case 0xB:
                jump_to_v0_address(&itp, mem, instr.address)
            case 0xC:
                set_register_to_random_byte_anded(mem, instr.x, instr.kk_byte)
            case 0xD:
                draw(scr, mem, instr.x, instr.y, instr.nibble)
            case:
                panic(fmt.aprintf("Unexpected command byte %X", command_byte))
        }

        if itp.program_counter + STEP_SIZE > len(mem.ram) {
            eof = true
            continue
        } else {
            itp.program_counter += STEP_SIZE
        }
    }

    fmt.print("Done\n")
}

sysaddr :: proc() {
    // @TODO: should probably be ignored?
}

call_subroutine :: proc(itp: ^Interpreter, mem: ^memory.Memory, address: u16) {
    mem.program_stack.pointer += 1
    mem.program_stack.stack[mem.program_stack.pointer] = itp.program_counter

    itp.program_counter = address
}

return_from_subroutine :: proc(itp: ^Interpreter, mem: ^memory.Memory) {
    itp.program_counter = mem.program_stack.stack[mem.program_stack.pointer]
    mem.program_stack.pointer -= 1
}

cls :: proc(scr: ^screen.Screen) {
    screen.clear_screen(scr)
}

// 3xkk - SE Vx, byte
// Skip next instruction if Vx = kk.
// The interpreter compares register Vx to kk, and if they are equal, increments the program counter by 2.
jump_if_equals :: proc(itp: ^Interpreter, mem: ^memory.Memory, register: u8, value: byte, comp: Equality) {
    value_x := memory.get_register(mem, register)
    equal := value_x == value

    switch comp {
        case .Eq:
            if equal  do itp.program_counter += STEP_SIZE
        case .Neq:
            if !equal do itp.program_counter += STEP_SIZE
    }
}


// 5xy0 - SE Vx, Vy
// Skip next instruction if Vx = Vy.
// The interpreter compares register Vx to register Vy, and if they are equal, increments the program counter by 2.
jump_if_registers_are_equal :: proc(itp: ^Interpreter, mem: ^memory.Memory, register_x, register_y: byte, comp: Equality) {
    value_x := memory.get_register(mem, register_x)
    value_y := memory.get_register(mem, register_y)

    equal := value_x == value_y

    switch comp {
        case .Eq:
            if equal  do itp.program_counter += STEP_SIZE
        case .Neq:
            if !equal do itp.program_counter += STEP_SIZE
    }
}

// 6xkk - LD Vx, byte
// Set Vx = kk.
// The interpreter puts the value kk into register Vx.
set_register_to_value :: proc(mem: ^memory.Memory, register: byte, value: byte) {
    memory.set_register(mem, register, value)
}

// 7xkk - ADD Vx, byte
// Set Vx = Vx + kk.
// Adds the value kk to the value of register Vx, then stores the result in Vx. 
increment_register_by_value :: proc(mem: ^memory.Memory, register: byte, value: byte) {
    sum := memory.get_register(mem, register) + value
    memory.set_register(mem, register, (sum % 0xFF))
}


// 8xy0 - LD Vx, Vy
// Set Vx = Vy.
// Stores the value of register Vy in register Vx.
store_value_from_vy_into_vx :: proc(mem: ^memory.Memory, register_x, register_y: byte) {
    memory.set_register(mem, register_x, memory.get_register(mem, register_y))
}

// 8xy1 - OR Vx, Vy
// Set Vx = Vx OR Vy.
// Performs a bitwise OR on the values of Vx and Vy, then stores the result in Vx. A bitwise OR compares the corrseponding bits from two values, and if either bit is 1, then the same bit in the result is also 1. Otherwise, it is 0.
// ====================================================================================================================================================================================================================================
// 8xy2 - AND Vx, Vy
// Set Vx = Vx AND Vy.
// Performs a bitwise AND on the values of Vx and Vy, then stores the result in Vx. A bitwise AND compares the corrseponding bits from two values, and if both bits are 1, then the same bit in the result is also 1. Otherwise, it is 0.
// ====================================================================================================================================================================================================================================
// 8xy3 - XOR Vx, Vy
// Set Vx = Vx XOR Vy.
// Performs a bitwise exclusive OR on the values of Vx and Vy, then stores the result in Vx. An exclusive OR compares the corrseponding bits from two values, and if the bits are not both the same, then the corresponding bit in the result is set to 1. Otherwise, it is 0.
do_bitwise_ops :: proc(mem: ^memory.Memory, register_x, register_y: byte, bitwise_op: Bitwise_Op) {
    result: byte

    switch bitwise_op {
        case .Or:
            result = memory.get_register(mem, register_x) | memory.get_register(mem, register_y)
        case .And:
            result = memory.get_register(mem, register_x) & memory.get_register(mem, register_y)
        case .Xor:
            result = memory.get_register(mem, register_x) ~ memory.get_register(mem, register_y)
    }

    memory.set_register(mem, register_x, byte(result))
}

add_registers :: proc(mem: ^memory.Memory, register_x, register_y: byte) {
    result := memory.get_register(mem, register_x) + memory.get_register(mem, register_y)

    carry := result > 0xFF ? 1 : 0

    memory.set_register(mem, register_x, (result % 0xFF))
    memory.set_register(mem, 0xF, byte(carry))
}

sub_registers :: proc(mem: ^memory.Memory, register_x, register_y: byte, reversed: Sub_Reversal) {
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

// 8xy6 - SHR Vx {, Vy}
// Set Vx = Vx SHR 1.
// If the least-significant bit of Vx is 1, then VF is set to 1, otherwise 0. Then Vx is divided by 2.
// =============================================================================================================
// 8xyE - SHL Vx {, Vy}
// Set Vx = Vx SHL 1.
// If the most-significant bit of Vx is 1, then VF is set to 1, otherwise to 0. Then Vx is multiplied by 2.
shift_register :: proc(mem: ^memory.Memory, register_x: byte, shift_direction: Shift_Direction) {
    vx := memory.get_register(mem, register_x)

    significant_bit, result: byte

    switch shift_direction {
        case .Left:
            significant_bit = vx << 1
            result = vx * 2
        case .Right:
            significant_bit = vx >> 1
            result = vx / 2
    }

    memory.set_register(mem, 0xF, byte(significant_bit == 1 ? 1 : 0))
    memory.set_register(mem, register_x, result)
}

set_register_i_to_address :: #force_inline proc(mem: ^memory.Memory, address: u16) {
    mem.register_i = address
}

jump_to_v0_address :: proc(itp: ^Interpreter, mem: ^memory.Memory, address: u16) {
    v0_value := memory.get_register(mem, 0x0)
    itp.program_counter = address + u16(v0_value)
}

set_register_to_random_byte_anded :: proc(mem: ^memory.Memory, register_x, kk_byte: byte) {
    rand := u8(rnd.uint32() & 0xFF) & kk_byte
    memory.set_register(mem, register_x, rand)
}

draw :: proc(scr: ^screen.Screen($W, $H), mem: ^memory.Memory, register_x, register_y, amount_to_read: byte) {
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

@(private)
sleep_ms :: proc(ms: time.Duration) {
    time.sleep(time.Millisecond * ms)
}