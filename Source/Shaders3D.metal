#include <metal_stdlib>
#include <simd/simd.h>
#import "ShaderTypes.h"

using namespace metal;

struct Transfer {
    float4 position [[position]];
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
    
    return out;
}

fragment float4 texturedFragmentShader
(
 Transfer data [[stage_in]],
 texture2d<float> tex2D [[texture(0)]],
 sampler sampler2D [[sampler(0)]])
{
    return data.color;
}

/////////////////////////////////////////////////////////////////////////

kernel void heightMapShader
(
 texture2d<float, access::read> outTexture [[texture(0)]],
 device TVertex* vData [[ buffer(0) ]],
 constant Control &control [[buffer(1)]],
 uint2 p [[thread_position_in_grid]])
{
    if(p.x > uint(255)) return; // vData dimension
    if(p.y > uint(255)) return;
 
    uint2 pp = p;   // centered on source pixels
    pp.x += (control.xSize - p.x) / 2;
    pp.y += (control.ySize - p.y) / 2;

    float4 c = outTexture.read(pp);
    float height = (c.x + c.y + c.z) * control.height / 3.0;
    
    int index = int(255 - p.y) * 256 + int(p.x);
    vData[index].pos.y = height;
    vData[index].color = c;
}
