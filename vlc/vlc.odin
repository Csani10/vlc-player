package vlc

import "core:c"
when ODIN_OS == .Linux do foreign import libvlc {
    "./lib/libvlc.so",
    "./lib/libvlccore.so",
}

libvlc_instance_t :: distinct rawptr
libvlc_media_t :: distinct rawptr
libvlc_media_player_t :: distinct rawptr
libvlc_time_t :: c.int64_t

libvlc_state_t :: enum c.int {
    libvlc_NothingSpecial = 0,
    libvlc_Opening,
    libvlc_Buffering,
    libvlc_Playing,
    libvlc_Paused,
    libvlc_Stopped,
    libvlc_Ended,
    libvlc_Error,
}

libvlc_video_lock_cb :: proc "c" (opaque: rawptr, planes: ^rawptr) -> rawptr
libvlc_video_unlock_cb :: proc "c" (opaque: rawptr, picture: rawptr, planes: [^]rawptr)
libvlc_video_display_cb :: proc "c" (opaque: rawptr, picture: rawptr)

foreign libvlc {
    libvlc_new :: proc(argc: c.int, argv: [^]cstring) -> libvlc_instance_t ---
    libvlc_media_new_path :: proc(p_instance: libvlc_instance_t, path: cstring) -> libvlc_media_t ---
    libvlc_media_player_get_length :: proc(p_mi: libvlc_media_player_t) -> libvlc_time_t ---
    libvlc_media_player_new :: proc(p_libvlc_instance: libvlc_instance_t) -> libvlc_media_player_t ---
    libvlc_media_player_new_from_media :: proc(p_md: libvlc_media_t) -> libvlc_media_player_t ---
    libvlc_media_player_set_media :: proc(p_mi: libvlc_media_player_t, p_md: libvlc_media_t) ---
    libvlc_media_player_get_time :: proc(p_mi: libvlc_media_player_t) -> libvlc_time_t ---
    libvlc_media_player_set_time :: proc(p_mi: libvlc_media_player_t, i_time: libvlc_time_t) ---
    libvlc_media_player_play :: proc(p_mi: libvlc_media_player_t) -> c.int ---
    libvlc_media_player_is_seekable :: proc(p_mi: libvlc_media_player_t) -> c.int ---
    libvlc_media_player_pause :: proc(p_mi: libvlc_media_player_t) -> c.int ---
    libvlc_media_player_is_playing :: proc(p_mi: libvlc_media_player_t) -> c.int ---
    libvlc_video_get_width  :: proc(mp: libvlc_media_player_t) -> c.uint ---
    libvlc_video_get_height :: proc(mp: libvlc_media_player_t) -> c.uint ---
    libvlc_media_player_stop :: proc(p_mi: libvlc_media_player_t) ---
    libvlc_media_player_get_state :: proc(p_mi: libvlc_media_player_t) -> libvlc_state_t ---
    libvlc_media_player_release :: proc(p_mi: libvlc_media_player_t) ---
    libvlc_audio_get_volume :: proc(p_mi: libvlc_media_player_t) -> c.int ---
    libvlc_audio_set_volume :: proc(p_mi: libvlc_media_player_t, i_volume: c.int) -> c.int ---
    libvlc_video_set_callbacks :: proc(mp: libvlc_media_player_t, lock: libvlc_video_lock_cb, unlock: libvlc_video_unlock_cb, display: libvlc_video_display_cb, opaque: rawptr) ---
    libvlc_video_set_format :: proc(mp: libvlc_media_player_t, chroma: cstring, width, height, pitch: c.uint) ---
    libvlc_media_release :: proc(p_md: libvlc_media_t) ---
    libvlc_release :: proc(p_instance: libvlc_instance_t) ---
    libvlc_get_version :: proc() -> cstring ---
}
