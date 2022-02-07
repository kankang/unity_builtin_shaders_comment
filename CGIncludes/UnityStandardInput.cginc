// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

#ifndef UNITY_STANDARD_INPUT_INCLUDED
#define UNITY_STANDARD_INPUT_INCLUDED

#include "UnityCG.cginc"
#include "UnityStandardConfig.cginc"
#include "UnityPBSLighting.cginc" // TBD: remove
#include "UnityStandardUtils.cginc"

//---------------------------------------
// Directional lightmaps & Parallax require tangent space too
#if (_NORMALMAP || DIRLIGHTMAP_COMBINED || _PARALLAXMAP)    // 法线贴图、光照贴图、视差贴图，需要开启切线空间
    #define _TANGENT_TO_WORLD 1
#endif

#if (_DETAIL_MULX2 || _DETAIL_MUL || _DETAIL_ADD || _DETAIL_LERP) // 开启细节贴图
    #define _DETAIL 1
#endif

//---------------------------------------
half4       _Color;             // 表面反照率颜色值 
half        _Cutoff;            // Cutoff值

sampler2D   _MainTex;           // 反照率贴图
float4      _MainTex_ST;        // 反照率贴图tiling和offset

sampler2D   _DetailAlbedoMap;   // 细节反照率纹理贴图
float4      _DetailAlbedoMap_ST;// 细节反照率贴图tiling和offset

sampler2D   _BumpMap;           // 法线纹理贴图
half        _BumpScale;         // 法线纹理系数

sampler2D   _DetailMask;        // 细节纹理屏蔽纹理
sampler2D   _DetailNormalMap;   // 细节法线纹理贴图
half        _DetailNormalMapScale;// 细节法线纹理系数

sampler2D   _SpecGlossMap;      // 镜面高光反射纹理贴图
sampler2D   _MetallicGlossMap;  // 金属度纹理贴图
half        _Metallic;          // 金属度
float       _Glossiness;        // 光泽度
float       _GlossMapScale;     // 光泽度系数

sampler2D   _OcclusionMap;      // AO纹理贴图
half        _OcclusionStrength; // AO遮蔽系数

sampler2D   _ParallaxMap;       // 视差纹理贴图
half        _Parallax;          // 视差纹理高度系数
half        _UVSec;             // 细节纹理坐标使用uv0、uv1

half4       _EmissionColor;     // 自发光颜色
sampler2D   _EmissionMap;       // 自发光纹理贴图

//-------------------------------------------------------------------------------------
// Input functions
// 顶点输入结构体
struct VertexInput
{
    float4 vertex   : POSITION;     // 顶点坐标（模型空间）
    half3 normal    : NORMAL;       // 法线向量
    float2 uv0      : TEXCOORD0;    // 第一层纹理坐标
    float2 uv1      : TEXCOORD1;    // 第二层纹理坐标
#if defined(DYNAMICLIGHTMAP_ON) || defined(UNITY_PASS_META)
    float2 uv2      : TEXCOORD2;    // 第三层纹理坐标
#endif
#ifdef _TANGENT_TO_WORLD
    half4 tangent   : TANGENT;  // 切线向量
#endif
    UNITY_VERTEX_INPUT_INSTANCE_ID  // 顶点 instance id
};
// 获取纹理坐标
float4 TexCoords(VertexInput v)
{
    float4 texcoord;
    texcoord.xy = TRANSFORM_TEX(v.uv0, _MainTex); // Always source from uv0     // 主贴图的uv坐标
    texcoord.zw = TRANSFORM_TEX(((_UVSec == 0) ? v.uv0 : v.uv1), _DetailAlbedoMap); // 细节贴图的uv坐标（根据UV Set选择uv0/uv1）
    return texcoord;
}
// 根据纹理坐标采样细节蒙版
half DetailMask(float2 uv)
{
    return tex2D (_DetailMask, uv).a;   // 使用细节蒙版纹理的alpha通道做为蒙版值
}
// 采样反照率纹理贴图
half3 Albedo(float4 texcoords)
{
    half3 albedo = _Color.rgb * tex2D (_MainTex, texcoords.xy).rgb; // 采样反照率贴图，并混合颜色
#if _DETAIL // 开启了细节纹理
    #if (SHADER_TARGET < 30)
        // SM20: instruction count limitation
        // SM20: no detail mask
        half mask = 1;  // 如果小于Shader Model 3，不使用细节纹理蒙版
    #else
        half mask = DetailMask(texcoords.xy);   // 采样mask值
    #endif
    half3 detailAlbedo = tex2D (_DetailAlbedoMap, texcoords.zw).rgb;    // 采样细节纹理的反照率颜色
    #if _DETAIL_MULX2   // 使用MULx2模式混合主、细颜色
        albedo *= LerpWhiteTo (detailAlbedo * unity_ColorSpaceDouble.rgb, mask);
    #elif _DETAIL_MUL   // 使用MUL模式混合主、细颜色
        albedo *= LerpWhiteTo (detailAlbedo, mask);
    #elif _DETAIL_ADD   // 使用ADD模式混合主、细颜色
        albedo += detailAlbedo * mask;
    #elif _DETAIL_LERP   // 使用LERP模式混合主、细颜色
        albedo = lerp (albedo, detailAlbedo, mask);
    #endif
#endif
    return albedo;
}
// 采样获取alpha值
half Alpha(float2 uv)
{
#if defined(_SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A)   // 如果主贴图的alpha通道被用来做光滑度，则返回颜色的alpha值
    return _Color.a;
#else // 否则，对主贴图的alpha通道进行采样，并和颜色的alpha值进行相乘
    return tex2D(_MainTex, uv).a * _Color.a;
#endif
}
// 计算环境光遮蔽
half Occlusion(float2 uv)
{
#if (SHADER_TARGET < 30) // 如果Shader Model小于3
    // SM20: instruction count limitation
    // SM20: simpler occlusion
    return tex2D(_OcclusionMap, uv).g;  // 直接采样AO贴图的g通道
#else // 如果大于 Shader Model 3
    half occ = tex2D(_OcclusionMap, uv).g;// AO贴图的g通道和AO强度进行插值，
    return LerpOneTo (occ, _OcclusionStrength);  // 1 - _OcclusionStrength + _OcclusionStrength * occ, UnityStandardUtils.cginc,L88
#endif
}
// 根据纹理坐标获取镜面高光反射颜色和光滑度
half4 SpecularGloss(float2 uv)
{
    half4 sg;
#ifdef _SPECGLOSSMAP    // 如果使用了镜面高光反射纹理贴图
    #if defined(_SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A) // 如果设置了反照率贴图的alpha是光滑度
        sg.rgb = tex2D(_SpecGlossMap, uv).rgb;  // 镜面高光反射颜色
        sg.a = tex2D(_MainTex, uv).a;   // 主贴图的alpha通道为光泽度
    #else // 镜面高光反射纹理贴图的alpha即是光泽度
        sg = tex2D(_SpecGlossMap, uv);  // 直接采样
    #endif
    sg.a *= _GlossMapScale; // 光泽度乘以系数
#else
    sg.rgb = _SpecColor.rgb;    // 如果没有使用镜面高光反射纹理贴图，则使用高光反射颜色属性
    #ifdef _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A // 如果设置了反照率贴图的alpha是光滑度
        sg.a = tex2D(_MainTex, uv).a * _GlossMapScale;   // 主贴图的alpha通道为光泽度乘以系数
    #else
        sg.a = _Glossiness; // 否则使用光泽度系数
    #endif
#endif
    return sg;
}
// 根据纹理坐标获取金属度和光滑度
half2 MetallicGloss(float2 uv)
{
    half2 mg;

#ifdef _METALLICGLOSSMAP // 如果使用了金属贴图
    #ifdef _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A // 如果设置了反照率贴图的alpha是光滑度
        mg.r = tex2D(_MetallicGlossMap, uv).r;  // 金属贴图的r通道为金属度
        mg.g = tex2D(_MainTex, uv).a;   // 主贴图的alpha通道为光泽度
    #else // 否则
        mg = tex2D(_MetallicGlossMap, uv).ra;   // 金属贴图的r通道为金属度，a通道为光泽度
    #endif
    mg.g *= _GlossMapScale; // 光滑度乘以系数
#else // 没有使用金属贴图
    mg.r = _Metallic;   // 使用金属度参数
    #ifdef _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A // 如果设置了反照率贴图的alpha是光滑度
        mg.g = tex2D(_MainTex, uv).a * _GlossMapScale;  // 主贴图的alpha通道为光泽度
    #else // 否则
        mg.g = _Glossiness; // 直接使用光泽度参数
    #endif
#endif
    return mg;
}
// 根据纹理坐标获取金属度和粗糙度
half2 MetallicRough(float2 uv)
{
    half2 mg;
#ifdef _METALLICGLOSSMAP // 如果使用了金属贴图
    mg.r = tex2D(_MetallicGlossMap, uv).r;  // 金属贴图的r通道为金属度
#else // 否则
    mg.r = _Metallic;   // 使用金属度参数
#endif

#ifdef _SPECGLOSSMAP // 如果使用了光泽度贴图
    mg.g = 1.0f - tex2D(_SpecGlossMap, uv).r;   // 粗糙度为 1 - 光泽度贴图的r通道
#else // 否则
    mg.g = 1.0f - _Glossiness;  // 粗糙度为 1 - 光泽度参数
#endif
    return mg;
}
// 计算自发光
half3 Emission(float2 uv)
{
#ifndef _EMISSION   // 如果没开启自发光就返回0
    return 0;
#else // 如果开启了自发光，对自发光纹理贴图进行采样，并和自发光颜色进行混合
    return tex2D(_EmissionMap, uv).rgb * _EmissionColor.rgb;
#endif
}

#ifdef _NORMALMAP
half3 NormalInTangentSpace(float4 texcoords) // 计算法线贴图中的法向量（法线贴图中存储的是rgb代表切线空间下的xyz偏移）
{
    half3 normalTangent = UnpackScaleNormal(tex2D (_BumpMap, texcoords.xy), _BumpScale); // 采样计算得出法向量

#if _DETAIL && defined(UNITY_ENABLE_DETAIL_NORMALMAP) // 如果使用了细节纹理
    half mask = DetailMask(texcoords.xy);   // 采样细节mask
    half3 detailNormalTangent = UnpackScaleNormal(tex2D (_DetailNormalMap, texcoords.zw), _DetailNormalMapScale); // 计算细节法向量
    #if _DETAIL_LERP // 如果使用插值的方法来整合主法向量和细节法向量
        normalTangent = lerp(
            normalTangent,
            detailNormalTangent,
            mask); // 插件得到法向量
    #else // 否则使用Blend的方法来整合主法向量和细节法向量
        normalTangent = lerp(
            normalTangent,
            BlendNormals(normalTangent, detailNormalTangent),
            mask);
    #endif
#endif

    return normalTangent;
}
#endif
// 根据观察方向进行视差采样
float4 Parallax (float4 texcoords, half3 viewDir)
{
#if !defined(_PARALLAXMAP) || (SHADER_TARGET < 30)  // 如果未开启视差纹理贴图或者小于Shader Model 3
    // Disable parallax on pre-SM3.0 shader target models
    return texcoords;   // 纹理坐标不做处理
#else
    half h = tex2D (_ParallaxMap, texcoords.xy).g;  // 对视差纹理采样，得到高度值
    float2 offset = ParallaxOffset1Step (h, _Parallax, viewDir);    // 根据高度和观察方向计算主纹理坐标的偏移，UnityStandardUtils.cginc, L80
    return float4(texcoords.xy + offset, texcoords.zw + offset);    // 纹理采样
#endif

}

#endif // UNITY_STANDARD_INPUT_INCLUDED
