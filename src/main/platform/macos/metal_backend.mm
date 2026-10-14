#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>
#import <AppKit/AppKit.h>
#include "metal_backend.hpp"
#include "metal_uniforms.h"
#include "frontend/config.hpp"
#include <cstring>
#include <vector>
#include <iostream>
namespace glb {
namespace {
SDL_Window* window = nullptr;
SDL_MetalView view = nullptr;
CAMetalLayer* layer;
id<MTLDevice> device;
id<MTLCommandQueue> queue;
id<MTLRenderPipelineState> pipeline;
id<MTLTexture> game, overlayTexture, white;
id<MTLCommandBuffer> pending;
id<CAMetalDrawable> drawable;
State::PixFmt format = State::PixFmt::RGBA;
MetalUniforms params;
SDL_Rect destination{};
bool overlayReady=false;
int interval=1;
std::vector<uint8_t> scratch;
MTLClearColor clearColor = MTLClearColorMake(0,0,0,1);
id<MTLTexture> texture(int w,int h,MTLPixelFormat fmt) {
    if (w<=0 || h<=0) return nil;
    auto d=[MTLTextureDescriptor texture2DDescriptorWithPixelFormat:fmt width:w height:h mipmapped:NO];
    d.storageMode=MTLStorageModeShared; d.usage=MTLTextureUsageShaderRead;
    return [device newTextureWithDescriptor:d];
}
void finish() {
    if(pending) { [pending waitUntilCompleted]; pending=nil; }
}
}
void set_game_pixel_format(State::PixFmt f) {format=f;}
void set_overlay_pixel_format_a8() {}
void resize_game_texture(int w,int h,State::PixFmt f) {
    finish(); format=f; game=texture(w,h,MTLPixelFormatRGBA8Unorm);
}
void on_drawable_resized() {
    if(!window || !layer) return;
    int w,h; SDL_Metal_GetDrawableSize(window,&w,&h);
    layer.drawableSize=CGSizeMake(w,h);
}
bool init(SDL_Window* w,int gw,int gh,int ow,int oh,const char* vs,const char* fs,bool,int,int) {
    @autoreleasepool {
        window=w; view=SDL_Metal_CreateView(w);
        if(!view) return false;
        layer=(__bridge CAMetalLayer*)SDL_Metal_GetLayer(view);
        device=MTLCreateSystemDefaultDevice();
        if(!device) { shutdown(); return false; }
        layer.device=device; layer.pixelFormat=MTLPixelFormatBGRA8Unorm;
        layer.framebufferOnly=YES; layer.displaySyncEnabled=interval!=0;
        queue=[device newCommandQueue];
        NSError* error=nil;
        NSString* path=[NSString stringWithUTF8String:(config.data.res_path+"Cannonball.metal").c_str()];
        NSString* source=[NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
        id<MTLLibrary> library=source ? [device newLibraryWithSource:source options:nil error:&error] : nil;
        if(!library) { std::cerr<<"Metal shader: "<<[[error description] UTF8String]<<'\n'; shutdown(); return false; }
        auto desc=[MTLRenderPipelineDescriptor new];
        desc.vertexFunction=[library newFunctionWithName:@"game_vertex"];
        desc.fragmentFunction=[library newFunctionWithName:@"game_fragment"];
        desc.colorAttachments[0].pixelFormat=layer.pixelFormat;
        pipeline=[device newRenderPipelineStateWithDescriptor:desc error:&error];
        if(!pipeline) { std::cerr<<"Metal pipeline: "<<[[error description] UTF8String]<<'\n'; shutdown(); return false; }
        params=MetalUniforms{}; params.mode=vs && fs ? config.video.shader_mode : 0;
        resize_game_texture(gw,gh,format);
        reallocate_overlay_storage(ow,oh);
        white=texture(1,1,MTLPixelFormatR8Unorm); uint8_t v=255;
        [white replaceRegion:MTLRegionMake2D(0,0,1,1) mipmapLevel:0 withBytes:&v bytesPerRow:1];
        on_drawable_resized();
        std::cout<<"Metal renderer: "<<[[device name] UTF8String]<<'\n';
        return true;
    }
}
void shutdown() {
    finish(); drawable=nil; game=nil; overlayTexture=nil; white=nil; pipeline=nil; queue=nil; device=nil; layer=nil;
    if(view) SDL_Metal_DestroyView(view);
    view=nullptr; window=nullptr; overlayReady=false; destination={};
}
void set_swap_interval(int v) {interval=v; if(layer) layer.displaySyncEnabled=v!=0;}
int swap_interval() {return interval;}
void reallocate_overlay_storage(int w,int h) {finish(); overlayTexture=texture(w,h,MTLPixelFormatR8Unorm);overlayReady=false;}
void update_game_texture(const void* pixels,int pitch,int w,int h) {
    finish();
    if(!game || game.width!=w || game.height!=h) resize_game_texture(w,h,format);
    if(!game || !pixels) return;
    if(format==State::PixFmt::RGBA) {
        [game replaceRegion:MTLRegionMake2D(0,0,w,h) mipmapLevel:0 withBytes:pixels bytesPerRow:pitch];
        return;
    }
    scratch.resize(size_t(w)*h*4);
    for(int y=0;y<h;y++) {
        auto src=(const uint8_t*)pixels+size_t(y)*pitch;
        auto dst=scratch.data()+size_t(y)*w*4;
        for(int x=0;x<w;x++) {
            if(format==State::PixFmt::RGB555) {
                uint16_t v; memcpy(&v,src+x*2,2);
                // Engine packs R:G:B:A into bits 15..0 (GLES 5_5_5_1).
                dst[x*4]=((v>>11)&31)*255/31; dst[x*4+1]=((v>>6)&31)*255/31;
                dst[x*4+2]=((v>>1)&31)*255/31; dst[x*4+3]=255;
            } else if(format==State::PixFmt::ABGR) {
                for(int c=0;c<4;c++) dst[x*4+c]=src[x*4+3-c];
            } else memcpy(dst+x*4,src+x*4,4);
        }
    }
    [game replaceRegion:MTLRegionMake2D(0,0,w,h) mipmapLevel:0 withBytes:scratch.data() bytesPerRow:w*4];
}
void update_overlay_texture(const void* pixels,int pitch,int w,int h) {
    finish();
    if(!overlayTexture || overlayTexture.width!=w || overlayTexture.height!=h) reallocate_overlay_storage(w,h);
    if(overlayTexture) { [overlayTexture replaceRegion:MTLRegionMake2D(0,0,w,h) mipmapLevel:0 withBytes:pixels bytesPerRow:pitch]; overlayReady=true; }
}
void clear_overlay_texture() {overlayReady=false;}
void set_uniform(const char* name,float value) {
#define SET(field) if(!strcmp(name,#field)) {params.field=value; return;}
    SET(warpX) SET(warpY) SET(brightboost) SET(noiseIntensity) SET(vignette)
    SET(desat_inv0) SET(desat_inv1) SET(baseOff) SET(baseOn) SET(invMaskPitch) SET(inv2MaskPitch) SET(inv2Height)
#undef SET
}
void set_uniform2(const char* n,float x,float y) {
    if(!strcmp(n,"invExpand")) {params.expandX=x;params.expandY=y;}
    else if(!strcmp(n,"OutputSize")) {params.outputW=x;params.outputH=y;}
    else if(!strcmp(n,"u_Time")) {params.timeX=x;params.timeY=y;}
}
void set_present_rect_pixels_top_left(int x,int y,int w,int h) {destination={x,y,w,h};}
void set_overlay_rect_pixels_top_left(int,int,int,int) {} // overlay shares the game's UV domain
void clear(float r,float g,float b,float a) {clearColor=MTLClearColorMake(r,g,b,a);}
void draw(bool,bool showOverlay) {
    @autoreleasepool {
        finish(); on_drawable_resized();
        if(!game || layer.drawableSize.width<1 || layer.drawableSize.height<1) return;
        drawable=[layer nextDrawable]; if(!drawable) return;
        pending=[queue commandBuffer];
        auto pass=[MTLRenderPassDescriptor renderPassDescriptor];
        pass.colorAttachments[0].texture=drawable.texture;
        pass.colorAttachments[0].loadAction=MTLLoadActionClear;
        pass.colorAttachments[0].storeAction=MTLStoreActionStore;
        pass.colorAttachments[0].clearColor=clearColor;
        auto encoder=[pending renderCommandEncoderWithDescriptor:pass];
        [encoder setRenderPipelineState:pipeline];
        SDL_Rect r=destination;
        if(r.w<=0 || r.h<=0) r={0,0,(int)drawable.texture.width,(int)drawable.texture.height};
        [encoder setViewport:MTLViewport{double(r.x),double(r.y),double(r.w),double(r.h),0,1}];
        params.overlay=showOverlay && overlayReady;
        [encoder setFragmentBytes:&params length:sizeof(params) atIndex:0];
        [encoder setFragmentTexture:game atIndex:0];
        [encoder setFragmentTexture:params.overlay ? overlayTexture : white atIndex:1];
        [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
        [encoder endEncoding];
        [pending presentDrawable:drawable]; [pending commit]; drawable=nil;
    }
}
void present() {} // draw commits presentation; next upload waits before reusing textures
}

namespace glb {
bool self_test() {
    // Real GPU readback tests: uploads, padded row pitch, channel order, orientation,
    // both CRT variants with neutral settings, A8 overlay and renderer recreation.
    if(SDL_Init(SDL_INIT_VIDEO)!=0) return false;
    auto w=SDL_CreateWindow("Metal validation",0,0,64,64,SDL_WINDOW_METAL|SDL_WINDOW_HIDDEN);
    if(!w) return false;
    bool ok=true;
    for(int mode=0;mode<3 && ok;mode++) {
        config.video.shader_mode=mode;
        if(!init(w,2,2,2,2,mode ? "test" : nullptr,mode ? "test" : nullptr,false)) {ok=false;break;}
        for(auto fmt:{State::PixFmt::RGBA,State::PixFmt::ABGR,State::PixFmt::RGB555}) {
            // red, green / blue, white, with deliberately padded source rows
            const uint8_t rgba[24]={255,0,0,255, 0,255,0,255, 0,0,0,0, 0,0,255,255, 255,255,255,255, 0,0,0,0};
            uint8_t bytes[24]; memcpy(bytes,rgba,24);
            if(fmt==State::PixFmt::ABGR)
                for(int y=0;y<2;y++) for(int x=0;x<2;x++)
                    for(int c=0;c<4;c++) bytes[y*12+x*4+c]=rgba[y*12+x*4+3-c];
            const uint16_t rgb555[6]={0xf801,0x07c1,0, 0x003f,0xffff,0};
            resize_game_texture(2,2,fmt);
            update_game_texture(fmt==State::PixFmt::RGB555 ? (const void*)rgb555 : bytes,fmt==State::PixFmt::RGB555 ? 6 : 12,2,2);
            for(int masked=0;masked<2;masked++) {
                uint8_t mask[4]={255,0,255,255}; update_overlay_texture(mask,2,2,2);
                params.overlay=masked;
                auto d=[MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm width:2 height:2 mipmapped:NO];
                d.storageMode=MTLStorageModeShared; d.usage=MTLTextureUsageRenderTarget;
                auto out=[device newTextureWithDescriptor:d];
                auto pass=[MTLRenderPassDescriptor renderPassDescriptor];
                pass.colorAttachments[0].texture=out;
                pass.colorAttachments[0].loadAction=MTLLoadActionClear;
                pass.colorAttachments[0].storeAction=MTLStoreActionStore;
                auto command=[queue commandBuffer]; auto enc=[command renderCommandEncoderWithDescriptor:pass];
                [enc setRenderPipelineState:pipeline];
                [enc setFragmentBytes:&params length:sizeof(params) atIndex:0];
                [enc setFragmentTexture:game atIndex:0]; [enc setFragmentTexture:overlayTexture atIndex:1];
                [enc drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
                [enc endEncoding]; [command commit]; [command waitUntilCompleted];
                uint8_t result[16]; [out getBytes:result bytesPerRow:8 fromRegion:MTLRegionMake2D(0,0,2,2) mipmapLevel:0];
                const uint8_t expected[16]={0,0,255,255, 0,(uint8_t)(masked?0:255),0,255, 255,0,0,255, 255,255,255,255};
                if(command.status==MTLCommandBufferStatusError || memcmp(result,expected,16)!=0) {
                    std::cerr<<"Metal pixel validation failed: mode="<<mode<<" format="<<int(fmt)<<" overlay="<<masked<<'\n';ok=false;
                }
            }
        }
        shutdown();
    }
    shutdown(); SDL_DestroyWindow(w); SDL_Quit();
    std::cout<<"Metal GPU tests: "<<(ok?"PASS":"FAIL")<<'\n';return ok;
}
}
