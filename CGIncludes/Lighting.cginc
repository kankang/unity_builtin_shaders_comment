// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

#ifndef LIGHTING_INCLUDED
#define LIGHTING_INCLUDED

#include "UnityLightingCommon.cginc"
#include "UnityGBuffer.cginc"
#include "UnityGlobalIllumination.cginc"

struct SurfaceOutput {
    fixed3 Albedo;      // 物体表面的漫反射颜色（反照率纹理采样）
    fixed3 Normal;      // 物体表面的法线
    fixed3 Emission;    // 物体的自发光颜色
    half Specular;      // 物体的镜面反射系数，在[0, 1]范围
    fixed Gloss;        // 物体的镜面高光亮度值
    fixed Alpha;        // 物体的透明度
};

#ifndef USING_DIRECTIONAL_LIGHT
#if defined (DIRECTIONAL_COOKIE) || defined (DIRECTIONAL)
#define USING_DIRECTIONAL_LIGHT     // 使用了直接光照（直接光照、直接缓存）
#endif
#endif

#if defined(UNITY_SHOULD_SAMPLE_SH) || defined(LIGHTMAP_ON) || defined(DYNAMICLIGHTMAP_ON)
    #define UNITY_LIGHT_FUNCTION_APPLY_INDIRECT     // 使用了间接光照（球谐、光照纹理、动态光照纹理）
#endif

inline fixed4 UnityLambertLight (SurfaceOutput s, UnityLight light) // lambert光照函数
{
    fixed diff = max (0, dot (s.Normal, light.dir));

    fixed4 c;
    c.rgb = s.Albedo * light.color * diff;
    c.a = s.Alpha;
    return c;
}

inline fixed4 LightingLambert (SurfaceOutput s, UnityGI gi) // lambert光照模型，光照模型格式为LightingXXX
{
    fixed4 c;
    c = UnityLambertLight (s, gi.light);

    #ifdef UNITY_LIGHT_FUNCTION_APPLY_INDIRECT
        c.rgb += s.Albedo * gi.indirect.diffuse;    // 增加间接光照
    #endif

    return c;
}

inline half4 LightingLambert_Deferred (SurfaceOutput s, UnityGI gi, out half4 outGBuffer0, out half4 outGBuffer1, out half4 outGBuffer2)    // 延迟渲染的lambert光照模型
{ // 延迟渲染的lambert光照模型
    UnityStandardData data;
    data.diffuseColor   = s.Albedo;
    data.occlusion      = 1;
    data.specularColor  = 0;
    data.smoothness     = 0;
    data.normalWorld    = s.Normal;

    UnityStandardDataToGbuffer(data, outGBuffer0, outGBuffer1, outGBuffer2);

    half4 emission = half4(s.Emission, 1);

    #ifdef UNITY_LIGHT_FUNCTION_APPLY_INDIRECT
        emission.rgb += s.Albedo * gi.indirect.diffuse;
    #endif

    return emission;
}

inline void LightingLambert_GI (
    SurfaceOutput s,
    UnityGIInput data,
    inout UnityGI gi)
{
    gi = UnityGlobalIllumination (data, 1.0, s.Normal);
}

inline fixed4 LightingLambert_PrePass (SurfaceOutput s, half4 light)
{
    fixed4 c;
    c.rgb = s.Albedo * light.rgb;
    c.a = s.Alpha;
    return c;
}

// NOTE: some intricacy in shader compiler on some GLES2.0 platforms (iOS) needs 'viewDir' & 'h'
// to be mediump instead of lowp, otherwise specular highlight becomes too bright.
inline fixed4 UnityBlinnPhongLight (SurfaceOutput s, half3 viewDir, UnityLight light)   // BlinnPhong光照函数
{
    half3 h = normalize (light.dir + viewDir);

    fixed diff = max (0, dot (s.Normal, light.dir));

    float nh = max (0, dot (s.Normal, h));
    float spec = pow (nh, s.Specular*128.0) * s.Gloss;

    fixed4 c;
    c.rgb = s.Albedo * light.color * diff + light.color * _SpecColor.rgb * spec;
    c.a = s.Alpha;

    return c;
}
// BlinnPhong光照模型，光照模型格式为LightingXXX
inline fixed4 LightingBlinnPhong (SurfaceOutput s, half3 viewDir, UnityGI gi)
{
    fixed4 c;
    c = UnityBlinnPhongLight (s, viewDir, gi.light);

    #ifdef UNITY_LIGHT_FUNCTION_APPLY_INDIRECT
        c.rgb += s.Albedo * gi.indirect.diffuse;
    #endif

    return c;
}
// 延迟渲染的BlinnPhong光照模型
inline half4 LightingBlinnPhong_Deferred (SurfaceOutput s, half3 viewDir, UnityGI gi, out half4 outGBuffer0, out half4 outGBuffer1, out half4 outGBuffer2)
{
    UnityStandardData data;
    data.diffuseColor   = s.Albedo;
    data.occlusion      = 1;
    // PI factor come from StandardBDRF (UnityStandardBRDF.cginc:351 for explanation)
    data.specularColor  = _SpecColor.rgb * s.Gloss * (1/UNITY_PI);
    data.smoothness     = s.Specular;
    data.normalWorld    = s.Normal;

    UnityStandardDataToGbuffer(data, outGBuffer0, outGBuffer1, outGBuffer2);

    half4 emission = half4(s.Emission, 1);

    #ifdef UNITY_LIGHT_FUNCTION_APPLY_INDIRECT
        emission.rgb += s.Albedo * gi.indirect.diffuse;
    #endif

    return emission;
}

inline void LightingBlinnPhong_GI (
    SurfaceOutput s,
    UnityGIInput data,
    inout UnityGI gi)
{
    gi = UnityGlobalIllumination (data, 1.0, s.Normal);
}

inline fixed4 LightingBlinnPhong_PrePass (SurfaceOutput s, half4 light)
{
    fixed spec = light.a * s.Gloss;

    fixed4 c;
    c.rgb = (s.Albedo * light.rgb + light.rgb * _SpecColor.rgb * spec);
    c.a = s.Alpha;
    return c;
}

#ifdef UNITY_CAN_COMPILE_TESSELLATION
struct UnityTessellationFactors {
    float edge[3] : SV_TessFactor;
    float inside : SV_InsideTessFactor;
};
#endif // UNITY_CAN_COMPILE_TESSELLATION

// Deprecated, kept around for existing user shaders.
#define UNITY_DIRBASIS \
const half3x3 unity_DirBasis = half3x3( \
  half3( 0.81649658,  0.0,        0.57735027), \
  half3(-0.40824830,  0.70710678, 0.57735027), \
  half3(-0.40824830, -0.70710678, 0.57735027) \
);

// Deprecated, kept around for existing user shaders. Only sampling the flat lightmap now.
half3 DirLightmapDiffuse(in half3x3 dirBasis, fixed4 color, fixed4 scale, half3 normal, bool surfFuncWritesNormal, out half3 scalePerBasisVector)
{
    scalePerBasisVector = 1;
    return DecodeLightmap (color);
}

#endif
