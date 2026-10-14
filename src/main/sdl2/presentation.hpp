#pragma once
#include <SDL.h>
#ifdef __APPLE__
#include "platform/macos/metal_backend.hpp"
#else
#include "gl_backend.hpp"
#endif
namespace presentation {
inline void drawable_size(SDL_Window* window, int* w, int* h) {
#ifdef __APPLE__
    SDL_Metal_GetDrawableSize(window, w, h);
#else
    SDL_GL_GetDrawableSize(window, w, h);
#endif
}
inline int swap_interval() {
#ifdef __APPLE__
    return glb::swap_interval();
#else
    return SDL_GL_GetSwapInterval();
#endif
}
}
