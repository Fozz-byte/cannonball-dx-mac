#pragma once
struct MetalUniforms {
    float warpX=0, warpY=0, expandX=1, expandY=1;
    float brightboost=1, noiseIntensity=0, vignette=0, desat_inv0=1;
    float desat_inv1=1, baseOff=1, baseOn=1, invMaskPitch=1.0f/3;
    float inv2MaskPitch=1.0f/6, inv2Height=0.5f, timeX=0, timeY=0;
    float outputW=1, outputH=1;
    int mode=0, overlay=0;
};
