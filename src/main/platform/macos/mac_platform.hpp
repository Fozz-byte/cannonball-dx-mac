#pragma once
#include <string>
struct SDL_Window;
namespace mac_platform {
bool initialize();
bool ensure_roms(bool interactive = true);
void install_menu();
std::string resources();
std::string user_data();
std::string music();
std::string saved_rom_path();
void pause();
void update_pause_title();
void choose_roms();
void begin_events();
void set_game_window(SDL_Window* window);
void sync_input_capture();
void shortcut_pause();
void shortcut_roms();
}
