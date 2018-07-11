#include <metal_stdlib>
#include <simd/simd.h>
#import "ShaderTypes.h"

using namespace metal;

struct Transfer {
    float4 position [[position]];
    float4 lighting;
    float4 color;
};

vertex Transfer texturedVertexShader
(
 device TVertex* vData [[ buffer(0) ]],
 constant ConstantData& constantData [[ buffer(1) ]],
 unsigned int vid [[ vertex_id ]])
{
    Transfer out;
    TVertex v = vData[vid];
    
    out.color = v.color;
    out.position = constantData.mvp * float4(v.pos, 1.0);
    
    float intensity = 0.2 + saturate(dot(vData[vid].nrm.rgb, constantData.light));
    out.lighting = float4(intensity,intensity,intensity,1);
    
    return out;
}

fragment float4 texturedFragmentShader
(
 Transfer data [[stage_in]])
{
    return data.color * data.lighting;
}

/////////////////////////////////////////////////////////////////////////

kernel void heightMapShader
(
 texture2d<float, access::read> srcTexture [[texture(0)]],
 device TVertex* vData      [[ buffer(0) ]],
 constant Control &control  [[ buffer(1) ]],
 uint2 p [[thread_position_in_grid]])
{
    if(p.x > 255 || p.y > 255) return; // threadCount mismatch
    
    int2 pp = int2(p);   // centered on source pixels
    int size = 256;
    switch(control.zoom) {
        case 0 :  // zoom in
            pp.x /= 2;
            pp.y /= 2;
            size = 128;
            break;
        case 2 :  // zoom out
            pp.x *= 2;
            pp.y *= 2;
            size = 512;
            break;
    }
    
    pp.x += (control.xSize - size) / 2;
    pp.y += (control.ySize - size) / 2;
    
    float4 c = srcTexture.read(uint2(pp));
    float height = (c.x + c.y + c.z) * control.height / 3.0;
    
    int index = int(255 - p.y) * 256 + int(p.x);
    vData[index].pos.y = height;
    vData[index].color = c;
}

/////////////////////////////////////////////////////////////////////////

kernel void smoothingShader
(
 constant TVertex* src      [[ buffer(0) ]],
 device TVertex* dst        [[ buffer(1) ]],
 constant Control &control  [[ buffer(2) ]],
 uint2 p [[thread_position_in_grid]])
{
    if(control.smooth == 0) return;
    if(p.x > 255 || p.y > 255) return; // threadCount mismatch
    
    int index = int(p.y) * 256 + int(p.x);
    
    if(p.x < 1 || p.x > 254 || p.y < 1 || p.y > 254) {
        dst[index] = src[index];
        return;
    }
    
    TVertex v = src[index];
    
    for(int x = -1; x <= 1; ++x) {
        if(x == 0) continue;
        for(int y = -1; y <= 1; ++y) {
            if(y == 0) continue;
            
            int index2 = index + y * 256 + x;
            v.pos.y += src[index2].pos.y;
            v.color += src[index2].color;
        }
    }
    
    v.pos.y /= 7;  // mathematically should be 9, but this works better
    v.color /= 7;
    
    dst[index] = v;
}

/////////////////////////////////////////////////////////////////////////
// smoothing shader skips the edge vertices.
// this routine sets edge data to match neighbors.

kernel void edgeShader
(
 device TVertex* v [[ buffer(0) ]],
 uint2 p [[thread_position_in_grid]])
{
    if(p.x > 255 || p.y > 255) return; // threadCount mismatch
    
    int index = int(p.y) * 256 + int(p.x);
    int index2 = index;
    
    if(p.x == 0) index2 += 1; else if(p.x == 255) index2 -= 1;
    if(p.y == 0) index2 += 256; else if(p.y == 255) index2 -= 256;
    
    if(index2 != index) {
        v[index].pos.y = v[index2].pos.y;
        v[index].color = v[index2].color;
    }
}

/////////////////////////////////////////////////////////////////////////

kernel void normalShader
(
 device TVertex* v [[ buffer(0) ]],
 uint2 p [[thread_position_in_grid]])
{
    if(p.x > 255 || p.y > 255) return; // threadCount mismatch
    
    int i = int(p.y) * 256 + int(p.x);
    int i2 = i + ((p.x < 255) ? 1 : -1);
    int i3 = i + ((p.y < 255) ? 256 : -256);
    
    TVertex v1 = v[i];
    TVertex v2 = v[i2];
    TVertex v3 = v[i3];
    
    v[i].nrm = normalize(cross(v1.pos - v2.pos, v1.pos - v3.pos));
}
