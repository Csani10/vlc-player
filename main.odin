package main

import "core:strings"
import "core:os"
import rl "vendor:raylib"

main :: proc() {
    /*if len(os.args) < 2 {
        os.exit(1)
    }*/

    rl.SetConfigFlags({rl.ConfigFlag.WINDOW_RESIZABLE})
    rl.InitWindow(1280, 720, "vlc-player")

    player: Player

    path: cstring
    if len(os.args) < 2 {
        path = strings.clone_to_cstring("")
    } else {
        path = strings.clone_to_cstring(os.args[1])
    }
    if !PlayerInit(&player, path) {
        rl.CloseWindow()
        os.exit(1)
    }

    rl.SetTargetFPS(60)

    for !rl.WindowShouldClose() {
        PlayerUpdate(&player)

        rl.BeginDrawing()

        rl.ClearBackground(rl.Color{13, 13, 13, 255})

        PlayerDraw(&player)

        rl.EndDrawing()
    }

    PlayerDestroy(&player)

    rl.CloseWindow()
}