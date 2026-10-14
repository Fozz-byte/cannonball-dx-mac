#include <metal_stdlib>
using namespace metal;
// Metal translation of James Pearce's CannonBall-SE CRT shaders, copyright 2025.
struct Params {
    float warpX, warpY, expandX, expandY;
    float brightboost, noiseIntensity, vignette, desat_inv0;
    float desat_inv1, baseOff, baseOn, invMaskPitch;
    float inv2MaskPitch, inv2Height, timeX, timeY;
    float outputW, outputH;
    int mode, overlay;
};
struct Vertex { float4 position [[position]]; float2 uv; };
vertex Vertex game_vertex(uint id [[vertex_id]]) {
    const float2 p[3] = {float2(-1,1), float2(3,1), float2(-1,-3)};
    const float2 uv[3] = {float2(0,0), float2(2,0), float2(0,2)};
    return {float4(p[id],0,1), uv[id]};
}
fragment float4 game_fragment(Vertex v [[stage_in]],
    texture2d<float> game [[texture(0)]], texture2d<float> overlay [[texture(1)]],
    constant Params& p [[buffer(0)]]) {
    constexpr sampler linearSampler(coord::normalized, address::clamp_to_edge, filter::linear);
    constexpr sampler nearestSampler(coord::normalized, address::clamp_to_edge, filter::nearest);
    float2 uv = v.uv;
    if (p.mode != 0) {
        uv = ((uv - 0.5) * float2(p.expandX,p.expandY) + 0.5) * 2 - 1;
        uv *= float2(1+uv.y*uv.y*p.warpX, 1+uv.x*uv.x*p.warpY);
        uv = uv * 0.5 + 0.5;
    }
    float3 c = p.mode == 0 ? game.sample(nearestSampler,uv).rgb : game.sample(linearSampler,uv).rgb;
    if (p.mode != 0) {
        float lum = (c.r+c.g+c.b)*0.33333*0.9;
        if (p.mode == 2) {
            float x = dot(uv + float2(p.timeX,p.timeY), float2(12.9898,78.233));
            x = fract(x * 0.15915494) * 6.2831853 - 3.1415927;
            float sine = 1.27323954*x - 0.405284735*x*abs(x);
            c += (fract(sine*43758.5453)-0.5)*p.noiseIntensity;
            float n = (dot(uv,uv)-(uv.x+uv.y)+0.5)*2;
            c = mix(float3(1),c,mix(p.desat_inv0,p.desat_inv1,n))*(1-n*p.vignette);
        }
        float2 mpos = floor(v.uv * float2(p.outputW,p.outputH));
        float2 mx = fract(mpos.xx * float2(p.invMaskPitch,p.inv2MaskPitch));
        float my = fract(mpos.y*p.inv2Height);
        float extra = mix(1-step(0.02f,my),1-step(0.02f,abs(my-0.5f)),step(0.5f,mx.y));
        float mask = mix(p.baseOff,p.baseOn,step(0.02f,mx.x)*(1-extra));
        c *= mix(mask,1.0f,lum)*p.brightboost;
    }
    if (p.overlay) c *= overlay.sample(nearestSampler,v.uv).r;
    return float4(c,1);
}
