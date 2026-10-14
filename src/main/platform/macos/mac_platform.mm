#import <AppKit/AppKit.h>
#include "mac_platform.hpp"
#include "frontend/config.hpp"
#include "roms.hpp"
#include "main.hpp"
#include "sdl2/input.hpp"
#include <SDL.h>
#include <filesystem>
#include <iostream>
#include <cstdio>
extern bool pause_engine;
namespace {
std::string resourcePath, userPath, pendingRomPath;
bool nativePauseHandled=false, nativeROMsHandled=false;
NSString* ns(const std::string& s) { return [NSString stringWithUTF8String:s.c_str()]; }
bool select_roms(bool startup) {
    mac_platform::pause();
    NSOpenPanel* panel=[NSOpenPanel openPanel];
    panel.title=@"Choose OutRun Revision B ROMs";
    panel.message=@"Select your OutRun ZIP archive or folder of extracted ROMs.";
    panel.canChooseFiles=YES; panel.canChooseDirectories=YES; panel.allowsMultipleSelection=NO;
    while([panel runModal]==NSModalResponseOK) {
        auto previous=config.data.rom_path;
        config.data.rom_path=panel.URL.path.UTF8String;
        bool valid;
        { Roms candidate; valid=candidate.load_revb_roms(config.sound.fix_samples); }
        if(valid) {
            auto oldPending=pendingRomPath;
            pendingRomPath=config.data.rom_path;
            if(!config.save()) {
                pendingRomPath=oldPending;
                NSAlert* a=[NSAlert new]; a.messageText=@"Could not save ROM selection";
                a.informativeText=@"Check that your user data folder is writable."; [a runModal];
                config.data.rom_path=previous; return false;
            }
            if(startup) return roms.load_revb_roms(config.sound.fix_samples);
            NSAlert* a=[NSAlert new]; a.messageText=@"ROM selection saved";
            a.informativeText=@"The new ROM location will be used next time you launch CannonBall DX for Mac.";
            [a runModal];
            // Running engine retains the old ROM set until restart.
            config.data.rom_path=previous;
            return true;
        }
        config.data.rom_path=previous;
        NSAlert* a=[NSAlert new]; a.messageText=@"Required ROM data is missing or invalid";
        a.informativeText=@"Choose an OutRun Revision B archive or extracted folder containing the required program, graphics and sound ROMs.";
        [a runModal];
    }
    return false;
}
}
@interface CannonBallActions : NSObject
- (void)showAbout:(id)sender;
- (void)chooseROMs:(id)sender;
- (void)openData:(id)sender;
- (void)quit:(id)sender;
- (void)pauseGame:(id)sender;
- (void)togglePause:(id)sender;
@end
@implementation CannonBallActions
- (void)showAbout:(id)sender {
    mac_platform::pause();
    [NSApp orderFrontStandardAboutPanel:sender];
}
- (void)chooseROMs:(id)sender { nativeROMsHandled=true; select_roms(false); }
- (void)openData:(id)sender { [[NSWorkspace sharedWorkspace] openURL:[NSURL fileURLWithPath:ns(userPath)]]; }
- (void)quit:(id)sender { SDL_Event event{}; event.type=SDL_QUIT; SDL_PushEvent(&event); }
- (void)pauseGame:(id)sender { mac_platform::pause(); }
- (void)togglePause:(id)sender { nativePauseHandled=true; pause_engine=!pause_engine; mac_platform::update_pause_title(); }
@end
namespace mac_platform {
static CannonBallActions* actions;
static id playbackActivity;
static Uint32 gameWindowID=0;
static void update_playback_activity() {
    if (!pause_engine && !playbackActivity) {
        // Avoid App Nap throttling active game/audio work. Pausing relinquishes
        // the activity, and idle system sleep remains allowed in normal use.
        playbackActivity=[NSProcessInfo.processInfo
            beginActivityWithOptions:NSActivityUserInitiatedAllowingIdleSystemSleep
            reason:@"CannonBall gameplay and audio playback"];
    } else if (pause_engine && playbackActivity) {
        [NSProcessInfo.processInfo endActivity:playbackActivity];
        playbackActivity=nil;
    }
}
void sync_input_capture() {
    SDL_Window* window=SDL_GetWindowFromID(gameWindowID);
    if (!window) return;
    const bool focused=NSApp.active && !NSApp.modalWindow && SDL_GetKeyboardFocus()==window;
    const bool playing=focused && !pause_engine && cannonball::state==cannonball::STATE_GAME;
    // The unattended soak must not take shortcuts away from the tester.
    const bool grab=playing && !std::getenv("CANNONBALL_SOAK");
    const bool previous=(SDL_GetWindowFlags(window)&SDL_WINDOW_KEYBOARD_GRABBED)!=0;
    if (previous!=grab) {
        SDL_SetWindowKeyboardGrab(window, grab ? SDL_TRUE : SDL_FALSE);
        if (std::getenv("CANNONBALL_INPUT_TRACE"))
            std::cout << "Mac keyboard capture: " << (grab ? "on" : "off") << std::endl;
    }
    const int cursor=playing && SDL_GetMouseFocus()==window ? SDL_DISABLE : SDL_ENABLE;
    if (SDL_ShowCursor(SDL_QUERY)!=cursor) {
        SDL_ShowCursor(cursor);
        if (std::getenv("CANNONBALL_INPUT_TRACE"))
            std::cout << "Mac cursor: " << (cursor==SDL_DISABLE ? "hidden" : "visible") << std::endl;
    }
}
void set_game_window(SDL_Window* window) {
    if (auto previous=SDL_GetWindowFromID(gameWindowID)) SDL_SetWindowKeyboardGrab(previous, SDL_FALSE);
    SDL_ShowCursor(SDL_ENABLE);
    gameWindowID=window ? SDL_GetWindowID(window) : 0;
    sync_input_capture();
}
std::string resources() {return resourcePath;}
std::string user_data() {return userPath;}
std::string music() {return userPath+"Music/";}
std::string saved_rom_path() {return pendingRomPath.empty() ? config.data.rom_path : pendingRomPath;}
void update_pause_title() {
    update_playback_activity();
    sync_input_capture();
    SDL_Window* window=SDL_GetWindowFromID(gameWindowID);
    if(window) SDL_SetWindowTitle(window, pause_engine ? "CannonBall DX for Mac — Paused (⌘P to resume)" : "CannonBall DX for Mac");
}
void pause() {
    // Explicit unattended soak mode keeps the animated demo workload active
    // while the tester uses other apps. Normal app focus behavior is unchanged.
    if (std::getenv("CANNONBALL_SOAK")) return;
    pause_engine=true; input.set_rumble(false);
    for(size_t i=0;i<sizeof(input.keys)/sizeof(input.keys[0]);++i) {
        input.keys[i]=input.keys_old[i]=input.keys_pressed[i]=false;
    }
    update_pause_title();
}
bool initialize() {
    @autoreleasepool {
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
        [NSApp finishLaunching];
        [NSApp activateIgnoringOtherApps:YES];
        resourcePath=std::string([NSBundle mainBundle].resourcePath.UTF8String)+"/res/";
        NSURL* base=[NSFileManager.defaultManager URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask].firstObject;
        // Preserve the existing data location across app display-name changes.
        userPath=std::string(base.path.UTF8String)+"/CannonBall DX/";
        // Explicit test override keeps automated tests out of the user's saved game data.
        if(const char* overridePath=std::getenv("CANNONBALL_USER_DATA")) userPath=std::string(overridePath)+"/";
        std::error_code error;
        std::filesystem::create_directories(music(),error);
        if(error) {
            NSAlert* alert=[NSAlert new]; alert.messageText=@"Cannot create the CannonBall DX for Mac data folder";
            alert.informativeText=ns(error.message()); [alert runModal]; return false;
        }
        if(!std::getenv("CANNONBALL_USER_DATA")) {
            freopen((userPath+"CannonBall.log").c_str(),"a",stdout);
            freopen((userPath+"CannonBall.log").c_str(),"a",stderr);
            setvbuf(stdout,nullptr,_IOLBF,0);
        }
        if(config.data.cfg_file=="config.xml") config.data.cfg_file=userPath+"config.xml";
        actions=[CannonBallActions new];
        update_playback_activity();
        [[NSWorkspace sharedWorkspace].notificationCenter addObserver:actions selector:@selector(pauseGame:) name:NSWorkspaceWillSleepNotification object:nil];
        return true;
    }
}
bool ensure_roms(bool interactive) {
    // Environment override is for local validation only and is never copied into the bundle.
    if(const char* path=std::getenv("CANNONBALL_ROM_PATH")) config.data.rom_path=path;
    if(roms.load_revb_roms(config.sound.fix_samples)) return true;
    return interactive && select_roms(true);
}
void choose_roms() { select_roms(false); }
void begin_events() { update_playback_activity(); sync_input_capture(); nativePauseHandled=nativeROMsHandled=false; }
void shortcut_pause() {
    if(!nativePauseHandled) { pause_engine=!pause_engine; update_pause_title(); }
}
void shortcut_roms() { if(!nativeROMsHandled) select_roms(false); }
void install_menu() {
    NSMenu* main=[NSMenu new];
    NSMenuItem* root=[NSMenuItem new]; [main addItem:root];
    NSMenu* app=[[NSMenu alloc] initWithTitle:@"CannonBall DX for Mac"]; root.submenu=app;
    auto add=[&](NSString* title,SEL selector,NSString* key) {
        NSMenuItem* item=[app addItemWithTitle:title action:selector keyEquivalent:key]; item.target=actions;
    };
    add(@"About CannonBall DX for Mac",@selector(showAbout:),@"");
    [app addItem:NSMenuItem.separatorItem];
    add(@"Pause / Resume",@selector(togglePause:),@"p");
    add(@"Choose ROMs…",@selector(chooseROMs:),@"o");
    add(@"Open User Data Folder",@selector(openData:),@"");
    [app addItem:NSMenuItem.separatorItem];
    add(@"Quit CannonBall DX for Mac",@selector(quit:),@"q");
    NSApp.mainMenu=main;
}
}
