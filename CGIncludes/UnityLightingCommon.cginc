// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

#ifndef UNITY_LIGHTING_COMMON_INCLUDED
#define UNITY_LIGHTING_COMMON_INCLUDED

fixed4 _LightColor0;
fixed4 _SpecColor;

struct UnityLight   // 直接光照
{
    half3 color;    // 直接光照光的颜色
    half3 dir;      // 直接光照的方向
    half  ndotl; // Deprecated: Ndotl is now calculated on the fly and is no longer stored. Do not used it.
};

struct UnityIndirect    // 间接光照
{
    half3 diffuse;  // 间接光照的漫反射贡献量
    half3 specular; // 间接光照的镜面反射贡献量
};

struct UnityGI  // 全局光照
{
    UnityLight light;
    UnityIndirect indirect;
};
// 全局光照数据结构体
struct UnityGIInput
{
    UnityLight light; // pixel light, sent from the engine，引擎传递过来的直接光照

    float3 worldPos;    // 世界空间中的位置
    half3 worldViewDir; // 世界空间中的观察方向
    half atten; // 阴影衰减值
    half3 ambient;  // 环境光颜色

    // interpolated lightmap UVs are passed as full float precision data to fragment shaders
    // so lightmapUV (which is used as a tmp inside of lightmap fragment shaders) should
    // also be full float precision to avoid data loss before sampling a texture.
    float4 lightmapUV; // .xy = static lightmap UV, .zw = dynamic lightmap UV，xy静态光贴图的uv，zw动态光贴图的uv

    #if defined(UNITY_SPECCUBE_BLENDING) || defined(UNITY_SPECCUBE_BOX_PROJECTION) || defined(UNITY_ENABLE_REFLECTION_BUFFERS)
    float4 boxMin[2];   // 光探针所占据空间包围盒范围的边界极小值
    #endif
    #ifdef UNITY_SPECCUBE_BOX_PROJECTION
    float4 boxMax[2];   // 光探针所占据空间包围盒范围的边界极大值
    float4 probePosition[2];    // 光探针位置
    #endif
    // HDR cubemap properties, use to decompress HDR texture
    float4 probeHDR[2]; // HDR光照探针，用来对HDR纹理进行解码
};

#endif
