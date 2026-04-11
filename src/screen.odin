package screen

import fmt "core:fmt"
import math "core:math"
import slice "core:slice"
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
            fmt.sbprint(&string_builder, (screen.pixels[y][x] ? "█" : " "))
        }
        fmt.sbprint(&string_builder, "\n")
    }

    fmt.println(strings.to_string(string_builder))
}

clear_screen :: proc(scr: ^Screen($W, $H)) {
    for y in 0 ..< scr.height {
        for x in 0 ..< scr.width {
            scr.pixels[y][x] = false
        }
    }
}

draw_sprite :: proc(
    screen: ^Screen($W, $H),
    x, y: byte,
    data: []byte,
) -> bool {
    collision := false

    coord_x := int(x) % screen.width
    coord_y := int(y) % screen.height

    current_sprite_row := 0
    current_row_pixel := 0

    row_max := coord_y + math.min(len(data), screen.height - coord_y)
    col_max := coord_x + math.min(8, screen.width - coord_x)

    for row in coord_y ..< row_max {
        pixels := byte_to_bool_slice(data[current_sprite_row])

        for col in coord_x ..< col_max {
            current_pixel := screen.pixels[row][col]
            new_pixel := current_pixel ~ pixels[current_row_pixel]

            if current_pixel && !new_pixel {
                collision = true
            }

            screen.pixels[row][col] = new_pixel

            current_row_pixel += 1
        }
        current_row_pixel = 0
        current_sprite_row += 1
    }

    return collision
}

byte_to_bool_slice :: proc(n: byte) -> []bool {
    bool_slice := make([]bool, 8)

    for i in 0 ..< 8 {
        bool_slice[7 - i] = (n >> u8(i)) & 0x1 == 1
    }

    return bool_slice
}
