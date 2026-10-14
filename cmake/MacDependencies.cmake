# Versions are deliberately fixed; all libraries are built for this target.
set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)
set(SDL_SHARED OFF CACHE BOOL "" FORCE)
set(SDL_STATIC ON CACHE BOOL "" FORCE)
set(SDL_TEST OFF CACHE BOOL "" FORCE)
FetchContent_Declare(mac_sdl URL https://github.com/libsdl-org/SDL/archive/refs/tags/release-2.32.10.tar.gz URL_HASH SHA256=03f9d7c191a837525c9cda6406af2f2e48be02b5e7eb03d949cc9f1e9ca41c8b)
FetchContent_MakeAvailable(mac_sdl)
# SDL's Cocoa keyboard grab is opt-in for non-sandboxed desktop apps. This
# enables its existing connection-scoped shortcut suppression implementation.
set_source_files_properties("${mac_sdl_SOURCE_DIR}/src/video/cocoa/SDL_cocoakeyboard.m"
    TARGET_DIRECTORY SDL2-static PROPERTIES COMPILE_DEFINITIONS SDL_MAC_NO_SANDBOX=1)
set(tinyxml2_BUILD_TESTING OFF CACHE BOOL "" FORCE)
FetchContent_Declare(mac_xml URL https://github.com/leethomason/tinyxml2/archive/refs/tags/11.0.0.tar.gz URL_HASH SHA256=5556deb5081fb246ee92afae73efd943c889cef0cafea92b0b82422d6a18f289)
FetchContent_MakeAvailable(mac_xml)
set(BUILD_PROGRAMS OFF CACHE BOOL "" FORCE)
set(BUILD_LIBOUT123 OFF CACHE BOOL "" FORCE)
set(BUILD_TESTING OFF CACHE BOOL "" FORCE)
FetchContent_Declare(mac_mpg URL https://www.mpg123.de/download/mpg123-1.32.9.tar.bz2 URL_HASH SHA256=03b61e4004e960bacf2acdada03ed94d376e6aab27a601447bd4908d8407b291 SOURCE_SUBDIR ports/cmake)
FetchContent_MakeAvailable(mac_mpg)
