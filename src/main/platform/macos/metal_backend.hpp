#pragma once
#include <SDL.h>
// Shared presentation contract. glb is retained to keep the upstream renderer diff small.
namespace glb {
struct State { enum class PixFmt { RGBA, ABGR, A8, RGB555 }; };
void set_game_pixel_format(State::PixFmt);
void set_overlay_pixel_format_a8();
bool init(SDL_Window*, int, int, int, int, const char*, const char*, bool, int = 0, int = 0);
void shutdown();
void on_drawable_resized();
void set_swap_interval(int);
int swap_interval();
void resize_game_texture(int, int, State::PixFmt);
void reallocate_overlay_storage(int, int);
void update_game_texture(const void*, int, int, int);
void update_overlay_texture(const void*, int, int, int);
void clear_overlay_texture();
void set_uniform(const char*, float);
void set_uniform2(const char*, float, float);
void set_present_rect_pixels_top_left(int, int, int, int);
void set_overlay_rect_pixels_top_left(int, int, int, int);
void clear(float, float, float, float);
void draw(bool, bool);
void present();
}
namespace glb { bool self_test(); }
