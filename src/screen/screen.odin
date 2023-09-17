package screen

import fmt "core:fmt"
import strings "core:strings"

Screen :: struct($W, $H: int) {
    width:  int,
    height: int,
    pixels: [H][W]bool,
}

make_screen :: proc($Width: int, $Height: int) -> ^Screen(Width, Height) {
    screen := new_clone(
        Screen(Width, Height){
            width = Width,
            height = Height,
            pixels = [Height][Width]bool{},
        },
    )

    return screen
}

draw_screen :: proc(screen: ^Screen($W, $H)) {
    string_builder := strings.builder_make()
    defer strings.builder_destroy(&string_builder)

    // clear the terminal
    fmt.sbprintf(&string_builder, "%c[%d;%df", 0x1B, 0, 0)

    for y in 0 ..< screen.height {
        for x in 0 ..< screen.width {
            fmt.sbprint(&string_builder, (screen.pixels[y][x] ? "x" : " "))
        }
        fmt.sbprint(&string_builder, "\n")
    }

    fmt.println(strings.to_string(string_builder))
}

clear_screen :: proc(screen: ^Screen($W, $H)) {
    fmt.print("\033c")
}

draw_sprite :: proc(
    screen: ^Screen($W, $H),
    x, y: byte,
    data: []byte,
) -> bool {
    any_xord, row_xord: bool = false, false

    for byte_val, index in data {
        row_index := (y + byte(index)) % byte(screen.height)

        row_xord = xor_bool_range(
            &screen.pixels[row_index],
            byte_to_bool_slice(byte_val),
            int(x),
        )

        if !any_xord && row_xord {
            any_xord = true
        }
    }

    return any_xord
}

xor_bool_range :: proc(target: ^[$W]bool, source: []bool, start: int) -> bool {
    unset := false
    target_length := len(target^)

    for pixel, index in source {
        actual_index := (start + index) % target_length
        old_state := target[actual_index]
        new_state := boolean_xor(target[actual_index], pixel)

        if !unset && (old_state == true && new_state == false) {
            unset = true
        }

        (target^)[actual_index] = new_state
    }

    return unset
}

boolean_xor :: proc(a, b: bool) -> bool {
    return a != b
}

byte_to_bool_slice :: proc(n: byte) -> (bool_slice: []bool) {
    byte_as_string := fmt.aprintf("%08b", n)

    bool_slice = make([]bool, 8)
    for char, index in byte_as_string {
        bool_slice[index] = char != '0'
    }

    return
}
