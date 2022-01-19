// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

#ifndef AUTOLIGHT_INCLUDED
#define AUTOLIGHT_INCLUDED

#include "HLSLSupport.cginc"
#include "UnityShadowLibrary.cginc"

// ----------------
//  Shadow helpers
// ----------------

// If none of the keywords are defined, assume directional? 默认是平行光
#if !defined(POINT) && !defined(SPOT) && !defined(DIRECTIONAL) && !defined(POINT_COOKIE) && !defined(DIRECTIONAL_COOKIE)
    #define DIRECTIONAL
#endif

// ---- Screen space direction light shadows helpers (any version)  屏幕空间方向光阴影
#if defined (SHADOWS_SCREEN)    // 如果没有启用屏幕空间层叠式阴影

    #if defined(UNITY_NO_SCREENSPACE_SHADOWS)
        UNITY_DECLARE_SHADOWMAP(_ShadowMapTexture); // 声明阴影映射纹理
        #define TRANSFER_SHADOW(a) a._ShadowCoord = mul( unity_WorldToShadow[0], mul( unity_ObjectToWorld, v.vertex ) ); // 从局部空间转换到阴影空间中的坐标值
        inline fixed unitySampleShadow (unityShadowCoord4 shadowCoord) // 阴影采样
        {
            #if defined(SHADOWS_NATIVE) // 硬件支持，直接采样阴影映射纹理
                fixed shadow = UNITY_SAMPLE_SHADOW(_ShadowMapTexture, shadowCoord.xyz);
                shadow = _LightShadowData.r + shadow * (1-_LightShadowData.r);  // 和阴影强度进行Lerp插值
                return shadow;
            #else // 硬件不支持，需要自己计算
                unityShadowCoord dist = SAMPLE_DEPTH_TEXTURE(_ShadowMapTexture, shadowCoord.xy);    // 深度值
                // tegra is confused if we use _LightShadowData.x directly 在Tegra处理器上如果把_LightShadowData.x直接传给max进行计算
                // with "ambiguous overloaded function reference max(mediump float, float)" 会因为参数类型精度的问题而导致混乱和不精确
                unityShadowCoord lightShadowDataX = _LightShadowData.x; // 阴影强度
                unityShadowCoord threshold = shadowCoord.z; // 远裁剪面过滤
                return max(dist > threshold, lightShadowDataX);
            #endif
        }

    #else // UNITY_NO_SCREENSPACE_SHADOWS 基于屏幕空间的阴影
        UNITY_DECLARE_SCREENSPACE_SHADOWMAP(_ShadowMapTexture); // 声明屏幕空间的纹理
        #define TRANSFER_SHADOW(a) a._ShadowCoord = ComputeScreenPos(a.pos);    // 定义阴影转换，如果是立体视角，则是将片元坐标变换到光源空间中；如果不是，变换到屏幕空间
        inline fixed unitySampleShadow (unityShadowCoord4 shadowCoord) // 阴影采样
        {
            fixed shadow = UNITY_SAMPLE_SCREEN_SHADOW(_ShadowMapTexture, shadowCoord);  // 在屏幕空间采样
            return shadow;
        }

    #endif

    #define SHADOW_COORDS(idx1) unityShadowCoord4 _ShadowCoord : TEXCOORD##idx1;    // 声明阴影贴图纹理坐标 float4
    #define SHADOW_ATTENUATION(a) unitySampleShadow(a._ShadowCoord) // 声明阴影计算函数
#endif

// -----------------------------
//  Shadow helpers (5.6+ version) unity5.6以上版本
// -----------------------------
// This version depends on having worldPos available in the fragment shader and using that to compute light coordinates. 此版本的函数根据传递进来的某片元在世界空间下的坐标、使用的光照贴图坐标，以及屏幕坐标计算阴影值
// if also supports ShadowMask (separately baked shadows for lightmapped objects) 同样也支持阴影屏蔽

half UnityComputeForwardShadows(float2 lightmapUV, float3 worldPos, float4 screenPos)
{
    //fade value 阴影淡化值
    float zDist = dot(_WorldSpaceCameraPos - worldPos, UNITY_MATRIX_V[2].xyz);  // 摄像机位置指向片元世界空间的位置，点乘观察空间的前向基向量，得到世界空间的距离
    float fadeDist = UnityComputeShadowFadeDistance(worldPos, zDist);   // 根据当前片元到当前摄像机的距离值，计算阴影的淡化程度
    half  realtimeToBakedShadowFade = UnityComputeShadowFade(fadeDist); // 计算阴影淡化程度（保证在远、近裁剪面之内）

    //baked occlusion if any    如果使用阴影蒙板，则返回烘焙的阴影衰减
    half shadowMaskAttenuation = UnitySampleBakedOcclusion(lightmapUV, worldPos);

    half realtimeShadowAttenuation = 1.0f;  // 声明平行光产生的实时阴影
    //directional realtime shadow
    #if defined (SHADOWS_SCREEN) // 如果是屏幕空间阴影
        #if defined(UNITY_NO_SCREENSPACE_SHADOWS) && !defined(UNITY_HALF_PRECISION_FRAGMENT_SHADER_REGISTERS) // 如果不是屏幕空间生成的阴影
            realtimeShadowAttenuation = unitySampleShadow(mul(unity_WorldToShadow[0], unityShadowCoord4(worldPos, 1))); // 将片元的世界坐标换到光源空间采样
        #else // 如果是屏幕空间，把片元的世界空间坐标转换到屏幕空间采样
            //Only reached when LIGHTMAP_ON is NOT defined (and thus we use interpolator for screenPos rather than lightmap UVs). See HANDLE_SHADOWS_BLENDING_IN_GI below.
            realtimeShadowAttenuation = unitySampleShadow(screenPos); // 只有在LightMap未开启的情况下才有效
        #endif
    #endif

    #if defined(UNITY_FAST_COHERENT_DYNAMIC_BRANCHING) && defined(SHADOWS_SOFT) && !defined(LIGHTMAP_SHADOW_MIXING)
    //avoid expensive shadows fetches in the distance where coherency will be good 避免执行性能消耗较大的阴影fetch操作
    UNITY_BRANCH // 明确的告知着色器编译器生成真正的动态分支功能
    if (realtimeToBakedShadowFade < (1.0f - 1e-2f)) // 非1不执行？？？
    {
    #endif

        //spot realtime shadow  计算聚光灯实时阴影
        #if (defined (SHADOWS_DEPTH) && defined (SPOT))
            #if !defined(UNITY_HALF_PRECISION_FRAGMENT_SHADER_REGISTERS)
                unityShadowCoord4 spotShadowCoord = mul(unity_WorldToShadow[0], unityShadowCoord4(worldPos, 1));
            #else
                unityShadowCoord4 spotShadowCoord = screenPos;
            #endif
            realtimeShadowAttenuation = UnitySampleShadowmap(spotShadowCoord);
        #endif

        //point realtime shadow 计算点光源实时阴影
        #if defined (SHADOWS_CUBE)
            realtimeShadowAttenuation = UnitySampleShadowmap(worldPos - _LightPositionRange.xyz);
        #endif

    #if defined(UNITY_FAST_COHERENT_DYNAMIC_BRANCHING) && defined(SHADOWS_SOFT) && !defined(LIGHTMAP_SHADOW_MIXING)
    }
    #endif
    // 最后混合实时的、阴影蒙板的，以及实时转烘焙的阴影值
    return UnityMixRealtimeAndBakedShadows(realtimeShadowAttenuation, shadowMaskAttenuation, realtimeToBakedShadowFade);
}

#if defined(SHADER_API_D3D11) || defined(SHADER_API_D3D12) || defined(SHADER_API_PSSL) || defined(UNITY_COMPILER_HLSLCC)
#   define UNITY_SHADOW_W(_w) _w    // 计算衰减时，dx11直接使用w
#else
#   define UNITY_SHADOW_W(_w) (1.0/_w)  // 计算衰减时，其他平台使用1/w
#endif

#if !defined(UNITY_HALF_PRECISION_FRAGMENT_SHADER_REGISTERS)    // 如果没有使用了半长度的浮点型寄存器（根据平台自动设置）
#    define UNITY_READ_SHADOW_COORDS(input) 0
#else
#    define UNITY_READ_SHADOW_COORDS(input) READ_SHADOW_COORDS(input)   // 根据不同的光照类型，使用不同的纹理坐标读取方法
#endif

#if defined(HANDLE_SHADOWS_BLENDING_IN_GI) // handles shadows in the depths of the GI function for performance reasons，如果定义了在照明下进行阴影混合，则提供一个带坐标的阴影计算版本
#   define UNITY_SHADOW_COORDS(idx1) SHADOW_COORDS(idx1)    // 声明阴影纹理坐标
#   define UNITY_TRANSFER_SHADOW(a, coord) TRANSFER_SHADOW(a)   // 声明阴影转换函数
#   define UNITY_SHADOW_ATTENUATION(a, worldPos) SHADOW_ATTENUATION(a)  // 场景阴影衰减
#elif defined(SHADOWS_SCREEN) && !defined(LIGHTMAP_ON) && !defined(UNITY_NO_SCREENSPACE_SHADOWS) // no lightmap uv thus store screenPos instead，如果定义了屏幕空间中处理阴影，且不使用贴图，没有使用层叠式屏幕空间阴影贴图
    // can happen if we have two directional lights. main light gets handled in GI code, but 2nd dir light can have shadow screen and mask.当有两个有向平行光时，主有向平行光在全局照明的相关代码中进行处理，第二个有向平行光在屏幕空间中进行阴影计算
    // - Disabled on ES2 because WebGL 1.0 seems to have junk in .w (even though it shouldn't)
#   if defined(SHADOWS_SHADOWMASK) && !defined(SHADER_API_GLES) //  如果使用了阴影蒙版，且不是在D3D9和OpenGLES平台下，那就从烘焙出来的光照贴图中取得阴影数据
#       define UNITY_SHADOW_COORDS(idx1) unityShadowCoord4 _ShadowCoord : TEXCOORD##idx1; // 因为阴影是在屏幕空间中进行处理，所以阴影坐标的x、y分量就是光照贴图的u、v贴图坐标换算而来的。
#       define UNITY_TRANSFER_SHADOW(a, coord) {a._ShadowCoord.xy = coord * unity_LightmapST.xy + unity_LightmapST.zw; a._ShadowCoord.zw = ComputeScreenPos(a.pos).xy;} // 对于用coord乘以unity_LightmapST.xy后再加上unity_LightmapST.zw的这样一个计算方式，当LIGHTMAP_ON为false时才能进入代码此处
#       define UNITY_SHADOW_ATTENUATION(a, worldPos) UnityComputeForwardShadows(a._ShadowCoord.xy, worldPos, float4(a._ShadowCoord.zw, 0.0, UNITY_SHADOW_W(a.pos.w))); //计算阴影衰减，转调用了UnityComputeForwardShadows函数
#   else //如果不从主光照贴图unity_LightmapST中计算阴影坐标，就用TRANSFER_SHADOW计算
#       define UNITY_SHADOW_COORDS(idx1) SHADOW_COORDS(idx1)
#       define UNITY_TRANSFER_SHADOW(a, coord) TRANSFER_SHADOW(a)
#       define UNITY_SHADOW_ATTENUATION(a, worldPos) UnityComputeForwardShadows(0, worldPos, a._ShadowCoord)
#   endif
#else //其他条件下
#   define UNITY_SHADOW_COORDS(idx1) unityShadowCoord4 _ShadowCoord : TEXCOORD##idx1;
#   if defined(SHADOWS_SHADOWMASK) //如果使用阴影蒙版，那么根据光照贴图纹理uv坐标求出阴影坐标
#       define UNITY_TRANSFER_SHADOW(a, coord) a._ShadowCoord.xy = coord.xy * unity_LightmapST.xy + unity_LightmapST.zw;
#       if (defined(SHADOWS_DEPTH) || defined(SHADOWS_SCREEN) || defined(SHADOWS_CUBE) || UNITY_LIGHT_PROBE_PROXY_VOLUME)//如果使用立方体阴影，或者光照探针代理体等有体积空间的阴影实现，需要把在世界空间中的坐标也传递进去
#           define UNITY_SHADOW_ATTENUATION(a, worldPos) UnityComputeForwardShadows(a._ShadowCoord.xy, worldPos, UNITY_READ_SHADOW_COORDS(a))
#       else//否则给UnityComputeForwardShadows函数传递的worldPos参数为0
#           define UNITY_SHADOW_ATTENUATION(a, worldPos) UnityComputeForwardShadows(a._ShadowCoord.xy, 0, 0)
#       endif
#   else   //如果不使用阴影蒙版，就不用实现transfer shadow的操作
#       if !defined(UNITY_HALF_PRECISION_FRAGMENT_SHADER_REGISTERS)
#           define UNITY_TRANSFER_SHADOW(a, coord)
#       else
#           define UNITY_TRANSFER_SHADOW(a, coord) TRANSFER_SHADOW(a)
#       endif
#       if (defined(SHADOWS_DEPTH) || defined(SHADOWS_SCREEN) || defined(SHADOWS_CUBE))
#           define UNITY_SHADOW_ATTENUATION(a, worldPos) UnityComputeForwardShadows(0, worldPos, UNITY_READ_SHADOW_COORDS(a))
#       else
#           if UNITY_LIGHT_PROBE_PROXY_VOLUME
#               define UNITY_SHADOW_ATTENUATION(a, worldPos) UnityComputeForwardShadows(0, worldPos, UNITY_READ_SHADOW_COORDS(a))
#           else
#               define UNITY_SHADOW_ATTENUATION(a, worldPos) UnityComputeForwardShadows(0, 0, 0)
#           endif
#       endif
#   endif
#endif

#ifdef POINT // 计算点光源的光亮度衰减的宏
sampler2D_float _LightTexture0; // 包含光源衰减信息的衰减纹理
unityShadowCoord4x4 unity_WorldToLight; // 世界空间转换到光源空间
#   define UNITY_LIGHT_ATTENUATION(destName, input, worldPos) \ 
        unityShadowCoord3 lightCoord = mul(unity_WorldToLight, unityShadowCoord4(worldPos, 1)).xyz; \ // lightCoord是一个采样值，在对后面的光源衰减纹理和采样时使用
        fixed shadow = UNITY_SHADOW_ATTENUATION(input, worldPos); \ // 计算当前阴影的衰减值
        fixed destName = tex2D(_LightTexture0, dot(lightCoord, lightCoord).rr).r * shadow; // 从光源衰减信息纹理中取出此处的衰减值，修整当前阴影的衰减值
#endif

#ifdef SPOT // 计算聚光灯光源的光亮度衰减的宏
sampler2D_float _LightTexture0; // 使用cookie时的衰减纹理
unityShadowCoord4x4 unity_WorldToLight; // 世界空间转换到光源空间
sampler2D_float _LightTextureB0;    // 聚光灯光源衰减纹理
inline fixed UnitySpotCookie(unityShadowCoord4 LightCoord)
{
    return tex2D(_LightTexture0, LightCoord.xy / LightCoord.w + 0.5).w;
}
inline fixed UnitySpotAttenuate(unityShadowCoord3 LightCoord)
{ // 使用距离的平方作为衰减值纹理图的索引
    return tex2D(_LightTextureB0, dot(LightCoord, LightCoord).xx).r;
}
#if !defined(UNITY_HALF_PRECISION_FRAGMENT_SHADER_REGISTERS) // 
#define DECLARE_LIGHT_COORD(input, worldPos) unityShadowCoord4 lightCoord = mul(unity_WorldToLight, unityShadowCoord4(worldPos, 1))
#else
#define DECLARE_LIGHT_COORD(input, worldPos) unityShadowCoord4 lightCoord = input._LightCoord
#endif
#   define UNITY_LIGHT_ATTENUATION(destName, input, worldPos) \
        DECLARE_LIGHT_COORD(input, worldPos); \
        fixed shadow = UNITY_SHADOW_ATTENUATION(input, worldPos); \
        fixed destName = (lightCoord.z > 0) * UnitySpotCookie(lightCoord) * UnitySpotAttenuate(lightCoord.xyz) * shadow;
#endif

#ifdef DIRECTIONAL // 有向平行光的光亮度不会随着光的传播距离的变化而发生衰减
#   define UNITY_LIGHT_ATTENUATION(destName, input, worldPos) fixed destName = UNITY_SHADOW_ATTENUATION(input, worldPos);
#endif

#ifdef POINT_COOKIE // 使用了点光源的cookie
samplerCUBE_float _LightTexture0; // 产生cookie的立方体纹理采样器，Light组件上指定的贴图
unityShadowCoord4x4 unity_WorldToLight;
sampler2D_float _LightTextureB0; // 点光源光线亮度衰减值纹理图
#   if !defined(UNITY_HALF_PRECISION_FRAGMENT_SHADER_REGISTERS)
#       define DECLARE_LIGHT_COORD(input, worldPos) unityShadowCoord3 lightCoord = mul(unity_WorldToLight, unityShadowCoord4(worldPos, 1)).xyz
#   else
#       define DECLARE_LIGHT_COORD(input, worldPos) unityShadowCoord3 lightCoord = input._LightCoord
#   endif
#   define UNITY_LIGHT_ATTENUATION(destName, input, worldPos) \
        DECLARE_LIGHT_COORD(input, worldPos); \
        fixed shadow = UNITY_SHADOW_ATTENUATION(input, worldPos); \
        fixed destName = tex2D(_LightTextureB0, dot(lightCoord, lightCoord).rr).r * texCUBE(_LightTexture0, lightCoord).w * shadow;
#endif

#ifdef DIRECTIONAL_COOKIE // 使用了方向光的cookie
sampler2D_float _LightTexture0; // 产生cookie的纹理采样器，Light组件上指定的贴图
unityShadowCoord4x4 unity_WorldToLight;
#   if !defined(UNITY_HALF_PRECISION_FRAGMENT_SHADER_REGISTERS)
#       define DECLARE_LIGHT_COORD(input, worldPos) unityShadowCoord2 lightCoord = mul(unity_WorldToLight, unityShadowCoord4(worldPos, 1)).xy
#   else
#       define DECLARE_LIGHT_COORD(input, worldPos) unityShadowCoord2 lightCoord = input._LightCoord
#   endif
#   define UNITY_LIGHT_ATTENUATION(destName, input, worldPos) \
        DECLARE_LIGHT_COORD(input, worldPos); \
        fixed shadow = UNITY_SHADOW_ATTENUATION(input, worldPos); \
        fixed destName = tex2D(_LightTexture0, lightCoord).w * shadow;
#endif


// -----------------------------
//  Light/Shadow helpers (4.x version)
// -----------------------------
// This version computes light coordinates in the vertex shader and passes them to the fragment shader.

// ---- Spot light shadows
#if defined (SHADOWS_DEPTH) && defined (SPOT)
#define SHADOW_COORDS(idx1) unityShadowCoord4 _ShadowCoord : TEXCOORD##idx1;
#define TRANSFER_SHADOW(a) a._ShadowCoord = mul (unity_WorldToShadow[0], mul(unity_ObjectToWorld,v.vertex));
#define SHADOW_ATTENUATION(a) UnitySampleShadowmap(a._ShadowCoord)
#endif

// ---- Point light shadows
#if defined (SHADOWS_CUBE)
#define SHADOW_COORDS(idx1) unityShadowCoord3 _ShadowCoord : TEXCOORD##idx1;
#define TRANSFER_SHADOW(a) a._ShadowCoord.xyz = mul(unity_ObjectToWorld, v.vertex).xyz - _LightPositionRange.xyz;
#define SHADOW_ATTENUATION(a) UnitySampleShadowmap(a._ShadowCoord)
#define READ_SHADOW_COORDS(a) unityShadowCoord4(a._ShadowCoord.xyz, 1.0)
#endif

// ---- Shadows off
#if !defined (SHADOWS_SCREEN) && !defined (SHADOWS_DEPTH) && !defined (SHADOWS_CUBE)
#define SHADOW_COORDS(idx1)
#define TRANSFER_SHADOW(a)
#define SHADOW_ATTENUATION(a) 1.0
#define READ_SHADOW_COORDS(a) 0
#else
#ifndef READ_SHADOW_COORDS
#define READ_SHADOW_COORDS(a) a._ShadowCoord
#endif
#endif

#ifdef POINT
#   define DECLARE_LIGHT_COORDS(idx) unityShadowCoord3 _LightCoord : TEXCOORD##idx;
#   define COMPUTE_LIGHT_COORDS(a) a._LightCoord = mul(unity_WorldToLight, mul(unity_ObjectToWorld, v.vertex)).xyz;
#   define LIGHT_ATTENUATION(a)    (tex2D(_LightTexture0, dot(a._LightCoord,a._LightCoord).rr).r * SHADOW_ATTENUATION(a))
#endif

#ifdef SPOT
#   define DECLARE_LIGHT_COORDS(idx) unityShadowCoord4 _LightCoord : TEXCOORD##idx;
#   define COMPUTE_LIGHT_COORDS(a) a._LightCoord = mul(unity_WorldToLight, mul(unity_ObjectToWorld, v.vertex));
#   define LIGHT_ATTENUATION(a)    ( (a._LightCoord.z > 0) * UnitySpotCookie(a._LightCoord) * UnitySpotAttenuate(a._LightCoord.xyz) * SHADOW_ATTENUATION(a) )
#endif

#ifdef DIRECTIONAL
#   define DECLARE_LIGHT_COORDS(idx)
#   define COMPUTE_LIGHT_COORDS(a)
#   define LIGHT_ATTENUATION(a) SHADOW_ATTENUATION(a)
#endif

#ifdef POINT_COOKIE
#   define DECLARE_LIGHT_COORDS(idx) unityShadowCoord3 _LightCoord : TEXCOORD##idx;
#   define COMPUTE_LIGHT_COORDS(a) a._LightCoord = mul(unity_WorldToLight, mul(unity_ObjectToWorld, v.vertex)).xyz;
#   define LIGHT_ATTENUATION(a)    (tex2D(_LightTextureB0, dot(a._LightCoord,a._LightCoord).rr).r * texCUBE(_LightTexture0, a._LightCoord).w * SHADOW_ATTENUATION(a))
#endif

#ifdef DIRECTIONAL_COOKIE
#   define DECLARE_LIGHT_COORDS(idx) unityShadowCoord2 _LightCoord : TEXCOORD##idx;
#   define COMPUTE_LIGHT_COORDS(a) a._LightCoord = mul(unity_WorldToLight, mul(unity_ObjectToWorld, v.vertex)).xy;
#   define LIGHT_ATTENUATION(a)    (tex2D(_LightTexture0, a._LightCoord).w * SHADOW_ATTENUATION(a))
#endif

#define UNITY_LIGHTING_COORDS(idx1, idx2) DECLARE_LIGHT_COORDS(idx1) UNITY_SHADOW_COORDS(idx2)
#define LIGHTING_COORDS(idx1, idx2) DECLARE_LIGHT_COORDS(idx1) SHADOW_COORDS(idx2)
#define UNITY_TRANSFER_LIGHTING(a, coord) COMPUTE_LIGHT_COORDS(a) UNITY_TRANSFER_SHADOW(a, coord)
#define TRANSFER_VERTEX_TO_FRAGMENT(a) COMPUTE_LIGHT_COORDS(a) TRANSFER_SHADOW(a)

#endif
