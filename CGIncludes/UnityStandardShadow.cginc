// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

#ifndef UNITY_STANDARD_SHADOW_INCLUDED
#define UNITY_STANDARD_SHADOW_INCLUDED

// NOTE: had to split shadow functions into separate file,
// otherwise compiler gives trouble with LIGHTING_COORDS macro (in UnityStandardCore.cginc)


#include "UnityCG.cginc"
#include "UnityShaderVariables.cginc"
#include "UnityStandardConfig.cginc"
#include "UnityStandardUtils.cginc"
// 如果UNITY_USE_DITHER_MASK_FOR_ALPHABLENDED_SHADOWS被启用，将会使用一张抖动纹理来实现半透明材质的阴影效果
#if (defined(_ALPHABLEND_ON) || defined(_ALPHAPREMULTIPLY_ON)) && defined(UNITY_USE_DITHER_MASK_FOR_ALPHABLENDED_SHADOWS)
    #define UNITY_STANDARD_USE_DITHER_MASK 1
#endif
// 在做一些alpha混合、测试、预乘等操作时，需要使用阴影贴图的uv坐标
// Need to output UVs in shadow caster, since we need to sample texture and do clip/dithering based on it
#if defined(_ALPHATEST_ON) || defined(_ALPHABLEND_ON) || defined(_ALPHAPREMULTIPLY_ON)
#define UNITY_STANDARD_USE_SHADOW_UVS 1
#endif
// 在某些平台上，不能使用空的阴影投射结构体数据
// Has a non-empty shadow caster output struct (it's an error to have empty structs on some platforms...)
#if !defined(V2F_SHADOW_CASTER_NOPOS_IS_EMPTY) || defined(UNITY_STANDARD_USE_SHADOW_UVS)
#define UNITY_STANDARD_USE_SHADOW_OUTPUT_STRUCT 1
#endif
// 如果启动了立体渲染的多例化技术，就要在顶点着色器函数中返回一个记录左右眼索引的结构体
#ifdef UNITY_STEREO_INSTANCING_ENABLED
#define UNITY_STANDARD_USE_STEREO_SHADOW_OUTPUT_STRUCT 1
#endif


half4       _Color;  // 表面反照率颜色值
half        _Cutoff; // Cutoff值
sampler2D   _MainTex; // 反照率贴图
float4      _MainTex_ST;    // _MainTex采样时使用的tiling和offset
#ifdef UNITY_STANDARD_USE_DITHER_MASK   // 如果需要半透材质的阴影效果
sampler3D   _DitherMaskLOD; // 声明一个抖动三维纹理
#endif

// Handle PremultipliedAlpha from Fade or Transparent shading mode
half4       _SpecColor; // 镜面高光反射颜色（不使用反射贴图时，设置的反射颜色）
half        _Metallic;  // 金属度（不使用金属度纹理贴图时，设置的金属度）
#ifdef _SPECGLOSSMAP    // 如果使用specular工作流，且设置了镜面高光反射纹理贴图
sampler2D   _SpecGlossMap;  // 镜面高光贴图
#endif
#ifdef _METALLICGLOSSMAP    // 如果使用了金属工作流，且设置金属度纹理贴图
sampler2D   _MetallicGlossMap;  // 金属度贴图
#endif

#if defined(UNITY_STANDARD_USE_SHADOW_UVS) && defined(_PARALLAXMAP) //如果使用了视差贴图
sampler2D   _ParallaxMap;   // 视差纹理贴图
half        _Parallax;  // 视差纹理高度系数
#endif
// 使用金属工作流时，阴影pass计算1-反射度
half MetallicSetup_ShadowGetOneMinusReflectivity(half2 uv)
{
    half metallicity = _Metallic;   // 如果没有使用金属度贴图，使用金属度属性
    #ifdef _METALLICGLOSSMAP
        metallicity = tex2D(_MetallicGlossMap, uv).r;   // 如果使用了金属度纹理贴图，就采样r通道
    #endif
    return OneMinusReflectivityFromMetallic(metallicity);
}
// 粗糙度工作流已废弃，就是金属工作流
half RoughnessSetup_ShadowGetOneMinusReflectivity(half2 uv)
{
    half metallicity = _Metallic;
#ifdef _METALLICGLOSSMAP
    metallicity = tex2D(_MetallicGlossMap, uv).r;
#endif
    return OneMinusReflectivityFromMetallic(metallicity);
}
// 使用镜面高光反射工作流时，阴影pass计算1-反射度
half SpecularSetup_ShadowGetOneMinusReflectivity(half2 uv)
{
    half3 specColor = _SpecColor.rgb;   // 如果没有使用镜面高光反射纹理贴图，使用镜面高光反射颜色
    #ifdef _SPECGLOSSMAP
        specColor = tex2D(_SpecGlossMap, uv).rgb;   // 如果使用了镜面高光反射纹理贴图，就采样贴图里的颜色值
    #endif
    return (1 - SpecularStrength(specColor));   // 因为不存在电介质的因素，所以直接返回1-高光反射颜色*高光反射强度
}

// SHADOW_ONEMINUSREFLECTIVITY(): workaround to get one minus reflectivity based on UNITY_SETUP_BRDF_INPUT，根据工作流选择1-反射度计算函数
#define SHADOW_JOIN2(a, b) a##b
#define SHADOW_JOIN(a, b) SHADOW_JOIN2(a,b)
#define SHADOW_ONEMINUSREFLECTIVITY SHADOW_JOIN(UNITY_SETUP_BRDF_INPUT, _ShadowGetOneMinusReflectivity)
// 顶点着色器输入数据结构体
struct VertexInput
{
    float4 vertex   : POSITION; // 顶点位置坐标
    float3 normal   : NORMAL;   // 顶点法向量
    float2 uv0      : TEXCOORD0;    // 第一层纹理坐标
    #if defined(UNITY_STANDARD_USE_SHADOW_UVS) && defined(_PARALLAXMAP)
        half4 tangent   : TANGENT;  // 顶点切线
    #endif
    UNITY_VERTEX_INPUT_INSTANCE_ID  // GPU实例化id
};

#ifdef UNITY_STANDARD_USE_SHADOW_OUTPUT_STRUCT  // 必须使用阴影输出结构体（不能返回空），就定义一个结构体
struct VertexOutputShadowCaster
{
    V2F_SHADOW_CASTER_NOPOS //  cube: float3 vec : TEXCOORD0 | tex2d: 空
    #if defined(UNITY_STANDARD_USE_SHADOW_UVS)
        float2 tex : TEXCOORD1; // 阴影贴图纹理坐标

        #if defined(_PARALLAXMAP)
            half3 viewDirForParallax : TEXCOORD2;   // 计算视差纹理使用的观察方向
        #endif
    #endif
};
#endif

#ifdef UNITY_STANDARD_USE_STEREO_SHADOW_OUTPUT_STRUCT // 需要定义立体渲染时的结构体
struct VertexOutputStereoShadowCaster
{
    UNITY_VERTEX_OUTPUT_STEREO  // 声明立体渲染时的左右眼索引
};
#endif

// We have to do these dances of outputting SV_POSITION separately from the vertex shader,
// and inputting VPOS in the pixel shader, since they both map to "POSITION" semantic on
// some platforms, and then things don't go well.

// 阴影投射顶点着色器
void vertShadowCaster (VertexInput v
    , out float4 opos : SV_POSITION
    #ifdef UNITY_STANDARD_USE_SHADOW_OUTPUT_STRUCT
    , out VertexOutputShadowCaster o
    #endif
    #ifdef UNITY_STANDARD_USE_STEREO_SHADOW_OUTPUT_STRUCT
    , out VertexOutputStereoShadowCaster os
    #endif
)
{
    UNITY_SETUP_INSTANCE_ID(v); // 设置顶点的instance id
    #ifdef UNITY_STANDARD_USE_STEREO_SHADOW_OUTPUT_STRUCT
        UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(os);  // 声明立体渲染时左右眼索引
    #endif
    TRANSFER_SHADOW_CASTER_NOPOS(o,opos)    // 阴影顶点位置转换到裁剪空间，并进行uv偏移，UnityCG.cginc, L932
    #if defined(UNITY_STANDARD_USE_SHADOW_UVS)
        o.tex = TRANSFORM_TEX(v.uv0, _MainTex); // (v.uv0.xy * _MainTex_ST.xy + _MainTex_ST.zw)

        #ifdef _PARALLAXMAP
            TANGENT_SPACE_ROTATION; // 构建切线空间基
            o.viewDirForParallax = mul (rotation, ObjSpaceViewDir(v.vertex));   // 计算视差纹理使用的观察方向
        #endif
    #endif
}
// 阴影投射片元着色器
half4 fragShadowCaster (UNITY_POSITION(vpos)    //  float4 pos : SV_POSITION
#ifdef UNITY_STANDARD_USE_SHADOW_OUTPUT_STRUCT
    , VertexOutputShadowCaster i
#endif
) : SV_Target
{
    #if defined(UNITY_STANDARD_USE_SHADOW_UVS)
        #if defined(_PARALLAXMAP) && (SHADER_TARGET >= 30)    // 如果开启了视差纹理
            half3 viewDirForParallax = normalize(i.viewDirForParallax); // 归一化视差视察向量
            fixed h = tex2D (_ParallaxMap, i.tex.xy).g; // 采样高度值
            half2 offset = ParallaxOffset1Step (h, _Parallax, viewDirForParallax);  // 通过高度计算uv偏移
            i.tex.xy += offset; // 视差后的uv坐标
        #endif

        #if defined(_SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A)
            half alpha = _Color.a;  // 如果主纹理的alpha通道用来做光滑度，那么alpha使用主颜色的alpha
        #else
            half alpha = tex2D(_MainTex, i.tex.xy).a * _Color.a;    // 否则采样alpha和主颜色的alpha进行混合
        #endif
        #if defined(_ALPHATEST_ON)  // alpha test
            clip (alpha - _Cutoff);
        #endif
        #if defined(_ALPHABLEND_ON) || defined(_ALPHAPREMULTIPLY_ON)
            #if defined(_ALPHAPREMULTIPLY_ON)   // 如果开启了alpha预乘
                half outModifiedAlpha; // 计算预乘后的alpha值
                PreMultiplyAlpha(half3(0, 0, 0), alpha, SHADOW_ONEMINUSREFLECTIVITY(i.tex), outModifiedAlpha);
                alpha = outModifiedAlpha;
            #endif
            #if defined(UNITY_STANDARD_USE_DITHER_MASK) // 这种Dither技术其实就是利用人眼的特性，我们看到的其实是有很多细小孔洞的阴影，由于这些空洞的大小和密度变化，在人眼看来就像是半透明了一样，但实际上真正的阴影颜色是没有变的
                // Use dither mask for alpha blended shadows, based on pixel position xy 基于片元位置和alpha等级来做dither texture采样
                // and alpha level. Our dither texture is 4x4x16. dither texture是4x4x16，z值代表透明度
                #ifdef LOD_FADE_CROSSFADE
                    #define _LOD_FADE_ON_ALPHA
                    alpha *= unity_LODFade.y;   // 计算lod淡入淡出（阴影透明度）
                #endif
                half alphaRef = tex3D(_DitherMaskLOD, float3(vpos.xy*0.25,alpha*0.9375)).a; // 对dither纹理采样
                clip (alphaRef - 0.01); // 裁剪掉alpha较低的纹素
            #else
                clip (alpha - _Cutoff); // 裁剪
            #endif
        #endif
    #endif // #if defined(UNITY_STANDARD_USE_SHADOW_UVS)

    #ifdef LOD_FADE_CROSSFADE
        #ifdef _LOD_FADE_ON_ALPHA
            #undef _LOD_FADE_ON_ALPHA
        #else
            UnityApplyDitherCrossFade(vpos.xy); // 进行LOD淡入淡出，UnityCG.cginc, L1106
        #endif
    #endif

    SHADOW_CASTER_FRAGMENT(i)   // 使用bias解决阴影渗漏的问题
}

#endif // UNITY_STANDARD_SHADOW_INCLUDED
