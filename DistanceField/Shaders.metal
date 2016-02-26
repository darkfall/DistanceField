//
//  Shaders.metal
//  DistanceField
//
//  Created by Robert Bu on 2/25/16.
//  Copyright (c) 2016 Robert Bu. All rights reserved.
//

#include <metal_stdlib>

using namespace metal;

struct VertexInOut
{
    float4  position [[position]];
    float2  uv;
};

vertex VertexInOut passThroughVertex(uint vid [[ vertex_id ]],
                                     constant packed_float4* position  [[ buffer(0) ]],
                                     constant packed_float2* uv    [[ buffer(1) ]])
{
    VertexInOut outVertex;
    
    outVertex.position = position[vid];
    outVertex.uv    = uv[vid];
    
    return outVertex;
};

fragment half4 passThroughFragment(VertexInOut inFrag [[stage_in]],
                                   texture2d<float> tex [[ texture(0) ]],
                                   sampler s [[ sampler(0) ]])
{
    return (half4)tex.sample(s, inFrag.uv);
};

float Mandelbox(float3 p)
{
    float foldL = 1.0;
    float foldR = 1.0;
    float foldRMin = 0.7;
    float scale = 2.3;
    float3 z = p;
    float factor = scale;
    
    int iterations = 30;
    for (int i = 0; i < iterations; ++i)
    {
        float m = 1.0;
        
        if (z.x > foldL) { z.x = 2.0 * foldL - z.x; }
        else if (z.x < -foldL) { z.x = -2.0 * foldL - z.x; }
        
        if (z.y > foldL) { z.y = 2.0 * foldL - z.y; }
        else if (z.y < -foldL) { z.y = -2.0 * foldL - z.y; }
        
        if (z.z > foldL) { z.z = 2.0 * foldL - z.z; }
        else if (z.z < -foldL) { z.z = -2.0 * foldL - z.z; }
        
        float r2 = dot(z, z);
        if (r2 < foldRMin * foldRMin)
        {
            m = ((foldR * foldR) / (foldRMin * foldRMin));
            z = z * m;
            factor = factor * m;
        }
        else if (r2 < foldR * foldR)
        {
            m = ((foldR * foldR) / (r2 * r2));
            z = z * m;
            factor = factor * m;
        }
        
        z = z * scale + p;
        factor = factor * scale + 1.0;
    }
    if (factor < 0.0)
    {
        factor = -factor;
    }
    return length(z) / factor;
}

struct Params
{
    packed_float3 eye;
    packed_float3 xStep;
    packed_float3 yStep;
    packed_float3 leftTopPoint;
    float viewportWidth;
    float viewportHeight;
    float fov;
};

#define DE Mandelbox

float3 GetNormal(float3 p, float eps)
{
    float3 normal = float3(DE(p + float3(eps, 0, 0)) - DE(p - float3(eps, 0, 0)),
                           DE(p + float3(0, eps, 0)) - DE(p - float3(0, eps, 0)),
                           DE(p + float3(0, 0, eps)) - DE(p - float3(0, 0, eps)));
    return normalize(normal);
                           
}

kernel void DistanceField(texture2d<float,access::write>  output  [[ texture(0) ]],
                          uint2 gid                               [[ thread_position_in_grid ]],
                          constant Params* params [[ buffer(0) ]])
{
    float2 xy = static_cast<float2>(gid);
    
    float3 strideH = params->xStep * xy.x;
    float3 strideV = params->yStep * xy.y;
    
    float3 dir = normalize(-params->eye + (params->leftTopPoint - strideH - strideV));
    
    float distance = 99999999.0f;
    float3 c;
    float3 p;
    float totalDistance = 0.0f;
    float threshold = DE(params->eye) * tan(params->fov / params->viewportHeight);
    bool hit = false;
    
    int iteration = 0;
    int maxIteration = 100;
    while (iteration < maxIteration)
    {
        p = params->eye + dir * totalDistance;
        distance = DE(p);
        totalDistance += distance;
        
        if (totalDistance > 1000.0f)
        {
            break;
        }
        
        if (distance < threshold)
        {
            hit = true;
            break;
        }
        iteration ++;
    }
    
    float k = 1.0f - (float)iteration / (float)maxIteration;
//    
    if (hit)
    {
        float3 normal = GetNormal(p, threshold);
        float3 color = float3(1.0f, 1.0f, 1.0f);
        float3 light = float3(-50.0f, 50.0f, -50.0f);
        float shadowStrength = 1.0f;
        
        float3 lightDir = normalize((light - p));
        float intense = clamp(dot(lightDir, normal), 0.0f, 1.0f);
        k = k * 0.5f;
        color = color * k;
        
        output.write(float4(color.xyz, 1.0f), gid);
    }
    else
    {
        //    output.write(float4(1, 0, 0, 1), gid);
    }
    
}