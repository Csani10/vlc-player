package main

import "core:sys/darwin/CoreFoundation"
import "core:path/filepath"
import "core:time"
import "core:strings"
import "core:fmt"
import "core:c"
import "core:mem"
import lvlc "./vlc"
import rl "vendor:raylib"

Player :: struct {
    vlc: lvlc.libvlc_instance_t,
    mp:  lvlc.libvlc_media_player_t,
    m: lvlc.libvlc_media_t,

    pixels: []u8,

    width: u32,
    height: u32,

    texture: rl.Texture2D,

    newFrame: bool,
    ready: bool,

    gui_timer: f32,
    volume_timer: f32,

    font: rl.Font,

    angle: f32,

    window_size: rl.Vector2,
    video_width: u32,
    video_height: u32,
    stretch: bool,
    
    status_message: cstring,
    status_timer: f32,
    status_priority: int,

    last_vol: c.int,
    show_help: bool,
}

lock :: proc "c" (opaque: rawptr, planes: ^rawptr) -> rawptr {
    p := cast(^Player)opaque

    planes^ = cast(rawptr)raw_data(p.pixels)

    return cast(rawptr)raw_data(p.pixels)
}

unlock :: proc "c" (opaque: rawptr, picture: rawptr, planes: [^]rawptr) {

}

display :: proc "c" (opaque: rawptr, picture: rawptr) {
    p := cast(^Player)opaque

    p.newFrame = true
}

screen_size_t :: struct {
    width: c.int,
    height: c.int
}

get_screen_size :: proc() -> screen_size_t {
    return screen_size_t{
        rl.GetScreenWidth(),
        rl.GetScreenHeight()
    }
}

PlayerShowStatusMsg :: proc(p: ^Player, message: cstring, priority: int = 0) {
    if priority < p.status_priority {
        return
    }

    if p.status_message != nil {
        delete(strings.clone_from_cstring(p.status_message))
    }

    p.status_message = strings.clone_to_cstring(
        strings.clone_from_cstring(message),
    )

    p.status_timer = 1
    p.status_priority = priority
}

PlayerInit :: proc(p: ^Player, filename: cstring) -> bool {
    mem.set(p, 0, size_of(Player))

    p.status_message = ""
    p.status_timer = 0
    p.gui_timer = 0
    p.angle = 0
    p.last_vol = 0
    p.stretch = false

    p.width = 1920
    p.height = 1080

    p.pixels = make([]u8, int(p.width * p.height * 4))

    args := [4]cstring{
        "--avcodec-hw=any",
        "--no-osd",
        "--no-video-title-show",
        "--intf=dummy",
    }

    p.vlc = lvlc.libvlc_new(4, &args[0])

    if p.vlc == nil {
        return false
    }
    
    p.mp = lvlc.libvlc_media_player_new(p.vlc)

    if strings.clone_from_cstring(filename) != "" {
        p.m = lvlc.libvlc_media_new_path(p.vlc, filename)

        if p.m == nil {
            return false
        }
        
        lvlc.libvlc_media_player_set_media(p.mp, p.m)
    }
    
    //lvlc.libvlc_media_release(media)

    lvlc.libvlc_video_set_callbacks(p.mp, lock, unlock, display, p)

    lvlc.libvlc_video_set_format(p.mp, "RGBA", c.uint(p.width), c.uint(p.height), c.uint(p.width * 4))

    img := rl.Image{
        data = raw_data(p.pixels),
        width = i32(p.width),
        height = i32(p.height),
        mipmaps = 1,
        format = rl.PixelFormat.UNCOMPRESSED_R8G8B8A8
    }

    p.texture = rl.LoadTextureFromImage(img)

    if strings.clone_from_cstring(filename) != "" {
        lvlc.libvlc_media_player_play(p.mp)

        // wait for VLC to open the stream
        for i in 0..<50 {
            p.video_width = lvlc.libvlc_video_get_width(p.mp)
            p.video_height = lvlc.libvlc_video_get_height(p.mp)

            if p.video_width != 0 && p.video_height != 0 {
                break
            }

            time.sleep(10 * time.Millisecond)
        }

        file_name := filepath.base(strings.clone_from_cstring(filename))

        PlayerShowStatusMsg(p, rl.TextFormat("Playing: %s", strings.clone_to_cstring(file_name)), 1)
    }

    if p.video_width == 0 || p.video_height == 0 {
        p.video_width = p.width
        p.video_height = p.height
    }

    p.ready = true

    p.font = rl.LoadFontEx("./resources/iosevka.ttf", 36, nil, 0)
    
    return true
}

PlayerUpdate :: proc(p: ^Player) {
    // handle timer countdowns
    if p.gui_timer > 0 {
        p.gui_timer -= rl.GetFrameTime()
    }

    if p.status_timer > 0 {
        p.status_timer -= rl.GetFrameTime()
    } else {
        p.status_priority = 0
    }

    if p.volume_timer > 0 {
        p.volume_timer -= rl.GetFrameTime()
    }

    // handle rotating
    if rl.IsKeyPressed(.E) || rl.IsKeyPressedRepeat(.E) {
        p.angle += 5
        PlayerShowStatusMsg(p, rl.TextFormat("Angle: %d", c.int(p.angle)))
    }

    if rl.IsKeyPressed(.Q) || rl.IsKeyPressedRepeat(.Q) {
        p.angle -= 5
        PlayerShowStatusMsg(p, rl.TextFormat("Angle: %d", c.int(p.angle)))
    }

    // handle fullscreen change
    if rl.IsKeyPressed(.F) {
        if !rl.IsWindowFullscreen() {
            p.window_size.x = f32(rl.GetScreenWidth())
            p.window_size.y = f32(rl.GetScreenHeight())
            monitor := rl.GetCurrentMonitor()
            width := rl.GetMonitorWidth(monitor)
            height := rl.GetMonitorHeight(monitor)
            rl.SetWindowSize(width, height)
            PlayerShowStatusMsg(p, "Fullscreen mode")
        } else {
            rl.SetWindowSize(c.int(p.window_size.x), c.int(p.window_size.y))
            PlayerShowStatusMsg(p, "Windowed mode")
        }
        rl.ToggleFullscreen()
    }

    // handle help key
    if rl.IsKeyPressed(.H) {
        p.show_help = !p.show_help
    }

    // check if video is not playing then make the gui visible
    if lvlc.libvlc_media_player_is_playing(p.mp) == 0 {
        p.gui_timer = 1
    }

    // handle pause, unpause
    if rl.IsKeyPressed(.SPACE) {
        p.gui_timer = 1

        if lvlc.libvlc_media_player_is_playing(p.mp) == 1 {
            lvlc.libvlc_media_player_pause(p.mp)
            PlayerShowStatusMsg(p, "Pause")
        } else {
            lvlc.libvlc_media_player_play(p.mp)
            PlayerShowStatusMsg(p, "Play")
        }
    }

    // handle volume changing
    vol := lvlc.libvlc_audio_get_volume(p.mp)
    if (rl.IsKeyPressedRepeat(.UP) || rl.IsKeyPressed(.UP) || rl.GetMouseWheelMove() > 0) && vol + 5 <= 150 {
        lvlc.libvlc_audio_set_volume(p.mp, vol + 5)

        PlayerShowStatusMsg(p, rl.TextFormat("Volume: %d%%", vol + 5))
    }

    if (rl.IsKeyPressedRepeat(.DOWN) || rl.IsKeyPressed(.DOWN) || rl.GetMouseWheelMove() < 0) && vol - 5 >= 0 {
        lvlc.libvlc_audio_set_volume(p.mp, vol - 5)
        p.volume_timer = 1

        PlayerShowStatusMsg(p, rl.TextFormat("Volume: %d%%", vol - 5))
    }

    // automatically make the volume bar visible when volume changed
    if p.last_vol != vol {
        p.volume_timer = 1
        p.last_vol = vol
        PlayerShowStatusMsg(p, rl.TextFormat("Volume: %d%%", vol))
    }

    // handle toggleing the stretch
    if rl.IsKeyPressed(.S) {
        p.stretch = !p.stretch
        if p.stretch {
            PlayerShowStatusMsg(p, "Stretch: ON")
        } else {
            PlayerShowStatusMsg(p, "Stretch: OFF")
        }
    }

    // make the gui visible when the mouse moves
    m_delta := rl.GetMouseDelta()
    if m_delta.x != f32(0) || m_delta.y != f32(0) {
        p.gui_timer = 1
    }

    // handle seeking
    if lvlc.libvlc_media_player_is_seekable(p.mp) == 1 {
        m_time := lvlc.libvlc_media_player_get_time(p.mp)
        if rl.IsKeyPressed(.LEFT) {
            if m_time - 5000 < 0 {
                lvlc.libvlc_media_player_set_time(p.mp, 0)
            } else {
                lvlc.libvlc_media_player_set_time(p.mp, m_time - 5000)
            }
            p.gui_timer = 1

            PlayerShowStatusMsg(p, "-5s")
        }

        if rl.IsKeyPressed(.RIGHT) {
            lvlc.libvlc_media_player_set_time(p.mp, m_time + 5000)
            p.gui_timer = 1

            PlayerShowStatusMsg(p, "+5s")
        }
    }

    // handle file dropping
    if rl.IsFileDropped() {
        files := rl.LoadDroppedFiles()

        lvlc.libvlc_media_player_stop(p.mp)
        lvlc.libvlc_media_release(p.m)

        file_name := filepath.base(strings.clone_from_cstring(files.paths[0]))

        p.m = lvlc.libvlc_media_new_path(p.vlc, files.paths[0])
        lvlc.libvlc_media_player_set_media(p.mp, p.m)
        lvlc.libvlc_media_player_play(p.mp)

        rl.UnloadDroppedFiles(files)

        for i in 0..<50 {
            p.video_width = lvlc.libvlc_video_get_width(p.mp)
            p.video_height = lvlc.libvlc_video_get_height(p.mp)

            if p.video_width != 0 && p.video_height != 0 {
                break
            }

            time.sleep(10 * time.Millisecond)
        }

        if p.video_width == 0 || p.video_height == 0 {
            p.video_width = p.width
            p.video_height = p.height
        }

        PlayerShowStatusMsg(p, rl.TextFormat("Playing: %s", strings.clone_to_cstring(file_name)), 1)
    }

    // some rendering stuff
    if !p.ready {
        return
    }

    if p.newFrame {
        rl.UpdateTexture(p.texture, raw_data(p.pixels))

        p.newFrame = false
    }
}

PlayerDrawTexture :: proc(p: ^Player) {
    if !p.stretch {
        screen_w := f32(rl.GetScreenWidth())
        screen_h := f32(rl.GetScreenHeight())

        video_aspect := f32(p.video_width) / f32(p.video_height)
        screen_aspect := screen_w / screen_h

        dest_w := screen_w
        dest_h := screen_h

        if video_aspect > screen_aspect {
            // crop top/bottom
            dest_h = screen_w / video_aspect
        } else {
            // crop left/right
            dest_w = screen_h * video_aspect
        }

        dest := rl.Rectangle{
            x = screen_w / 2,
            y = screen_h / 2,
            width = dest_w,
            height = dest_h,
        }

        origin := rl.Vector2{
            dest_w / 2,
            dest_h / 2,
        }

        rl.DrawTexturePro(
            p.texture,
            rl.Rectangle{
                x = 0,
                y = 0,
                width = f32(p.width),
                height = f32(p.height),
            },
            dest,
            origin,
            p.angle,
            rl.WHITE,
        )
    } else {
        dest := rl.Rectangle{
            f32(rl.GetScreenWidth()) / 2,
            f32(rl.GetScreenHeight()) / 2,
            f32(rl.GetScreenWidth()),
            f32(rl.GetScreenHeight()),
        }

        origin := rl.Vector2{
            dest.width / 2,
            dest.height / 2,
        }

        rl.DrawTexturePro(p.texture, rl.Rectangle{0, 0, f32(p.width), f32(p.height)}, dest, origin, p.angle, rl.WHITE)
    }
}

PlayerDrawGui :: proc(p: ^Player) {
    screen_size := get_screen_size()
    time := lvlc.libvlc_media_player_get_time(p.mp)
    length := lvlc.libvlc_media_player_get_length(p.mp)

    if p.gui_timer > 0 {
        rl.ShowCursor()
        percent := f32(time) / f32(length)

        rl.DrawRectangle(0, screen_size.height - 20, screen_size.width, 20, rl.ColorAlpha(rl.BLACK, 0.4))
        minutes := time / 1000 / 60
        seconds := time / 1000 % 60

        len_min := length / 1000 / 60
        len_sec := length / 1000 % 60
        time_text := rl.TextFormat("%02d:%02d / %02d:%02d", minutes, seconds, len_min, len_sec)
        text_size := rl.MeasureTextEx(p.font, time_text, 20, 0)
        rl.DrawTextEx(p.font, time_text, rl.Vector2{20, f32(screen_size.height)-20}, 20, 0, rl.WHITE)

        time_rec := rl.Rectangle{
            22 + text_size.x,
            f32(screen_size.height) - 18,
            f32(screen_size.width - 22 - c.int(text_size.x)) * percent,
            16,
        }
        rl.DrawRectangleRounded(time_rec, 0.5, 8, rl.WHITE)

        if lvlc.libvlc_media_player_is_playing(p.mp) == 1 {
            v1 := rl.Vector2{2, f32(screen_size.height - 18)}
            v2 := rl.Vector2{2, f32(screen_size.height - 2)}
            v3 := rl.Vector2{18, f32(screen_size.height - 10)}
            rl.DrawTriangle(v1, v2, v3, rl.WHITE)
        } else {
            rl.DrawRectangle(2, screen_size.height - 18, 5, 16, rl.WHITE)
            rl.DrawRectangle(20 - 5 - 2, screen_size.height - 18, 5, 16, rl.WHITE)
        }
    } else {
        rl.HideCursor()
    }
}

PlayerDrawStatusMsg :: proc(p: ^Player) {
    if p.status_timer > 0 {
        text_size := rl.MeasureTextEx(p.font, p.status_message, 36, 0)

        rec := rl.Rectangle{
            f32(rl.GetScreenWidth()) / 2 - text_size.x / 2 - 5, 
            30 - 5,
            text_size.x + 10,
            text_size.y + 10,
        }
        rl.DrawRectangleRounded(rec, 0.5, 8, rl.ColorAlpha(rl.BLACK, 0.4))
        rl.DrawTextEx(p.font, p.status_message, rl.Vector2{f32(rl.GetScreenWidth()) / 2 - text_size.x / 2, 30}, 36, 0, rl.WHITE)
    }
}

PlayerDrawVolumeBar :: proc(p: ^Player) {
    vol := lvlc.libvlc_audio_get_volume(p.mp)
    vol_max := 100

    if p.volume_timer > 0 {
        vol := lvlc.libvlc_audio_get_volume(p.mp)
        color := rl.WHITE

        vol_max := f32(100.0)
        if vol > 130 {
            vol_max = 150.0
            color = rl.RED
        } else if vol > 100 {
            vol_max = 150.0
            color = rl.ORANGE
        }

        vol_percent := f32(vol) / vol_max

        bar_width := 15
        bar_height := rl.GetScreenHeight() - 60

        filled_height := f32(bar_height) * vol_percent

        x := rl.GetScreenWidth() - 30 - i32(bar_width)
        y := rl.GetScreenHeight() - 30 - i32(filled_height)

        bg_rec := rl.Rectangle{
            f32(x) - 5,
            30 - 5,
            f32(bar_width) + 10,
            f32(bar_height) + 10,
        }
        rl.DrawRectangleRounded(bg_rec, 0.5, 8, rl.ColorAlpha(rl.BLACK, 0.4))

        // volume level
        vol_rec := rl.Rectangle{
            f32(x),
            f32(y),
            f32(bar_width),
            f32(filled_height),
        }

        rl.DrawRectangleRounded(vol_rec, 0.5, 8, color)
    }
}

PlayerDrawHelpText :: proc(p: ^Player) {
    if p.show_help {
        help_message := strings.clone_to_cstring(`space - play, pause
f - fullscreen toggle
up, down arrow, mouse scroll - volume adjust
left, right arrow - seek 5s
e, q - adjust angle by 5 degrees
s - toggle stretch
drag n' drop - open a video or audio
h - toggle help
esc - quit`)

        help_message_size := rl.MeasureTextEx(p.font, help_message, 36, 0)

        pos := rl.Vector2{
            f32(rl.GetScreenWidth()) / 2 - help_message_size.x / 2,
            f32(rl.GetScreenHeight()) / 2 - help_message_size.y / 2,
        }

        bg_rec := rl.Rectangle{
            pos.x - 5,
            pos.y - 5,
            help_message_size.x + 10,
            help_message_size.y + 10,
        }

        rl.DrawRectangleRounded(bg_rec, 0.15, 8, rl.ColorAlpha(rl.BLACK, 0.4))

        rl.DrawTextEx(
            p.font,
            help_message,
            pos,
            36,
            0,
            rl.WHITE,
        )
    }
}

PlayerDraw :: proc(p: ^Player) {
    PlayerDrawTexture(p)

    PlayerDrawGui(p)

    PlayerDrawStatusMsg(p)

    PlayerDrawVolumeBar(p)

    PlayerDrawHelpText(p)
}

PlayerDestroy :: proc(p: ^Player) {
    if p.m != nil {
        lvlc.libvlc_media_release(p.m)
    }

    if p.mp != nil {
        lvlc.libvlc_media_player_stop(p.mp)
        lvlc.libvlc_media_player_release(p.mp)
    }

    if p.vlc != nil {
        lvlc.libvlc_release(p.vlc)
    }

    rl.UnloadFont(p.font)
    rl.UnloadTexture(p.texture)

    delete(p.pixels)
}