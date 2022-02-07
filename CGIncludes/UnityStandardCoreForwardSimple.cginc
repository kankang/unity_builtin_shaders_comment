// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

#ifndef UNITY_STANDARD_CORE_FORWARD_SIMPLE_INCLUDED
#define UNITY_STANDARD_CORE_FORWARD_SIMPLE_INCLUDED

#include "UnityStandardCore.cginc"

//  Does not support: _PARALLAXMAP, DIRLIGHTMAP_COMBINED，Simple不支持视差纹理贴图
#define GLOSSMAP (defined(_SPECGLOSSMAP) || defined(_METALLICGLOSSMAP)) // 开启光泽度

#ifndef SPECULAR_HIGHLIGHTS     // 开启镜面高光反射
    #define SPECULAR_HIGHLIGHTS (!defined(_SPECULAR_HIGHLIGHTS_OFF))
#endif

struct VertexOutputBaseSimple
{
    UNITY_POSITION(pos);    // float4 pos : SV_POSITION
    float4 tex                          : TEXCOORD0;    // 顶点的第一层纹理坐标
    half4 eyeVec                        : TEXCOORD1; // w: grazingTerm  // 观察方向，w分量存储了掠射角项值（入射光线和反射平面的夹角）

    half4 ambientOrLightmapUV           : TEXCOORD2; // SH or Lightmap UV   球谐光照系数或者光贴图的坐标
    SHADOW_COORDS(3)    // 定义阴影纹理坐标 : TEXCOORD3
    UNITY_FOG_COORDS_PACKED(4, half4) // x: fogCoord, yzw: reflectVec   雾效纹理坐标 : TEXCOORD4

    half4 normalWorld                   : TEXCOORD5; // w: fresnelTerm  // 法线，w是菲涅尔方程的值

#ifdef _NORMALMAP // 如果使用了法线纹理贴图，则需要切线和副法线
    half3 tangentSpaceLightDir          : TEXCOORD6;    // 切线空间的光方向
    #if SPECULAR_HIGHLIGHTS // 如是开启了镜面高光反射
        half3 tangentSpaceEyeVec        : TEXCOORD7;    // 切线空间的观察方向
    #endif
#endif
#if UNITY_REQUIRE_FRAG_WORLDPOS // 如果片元需要顶点世界坐标, UnityStandardConfig.cginc
    float3 posWorld                     : TEXCOORD8;    // 世界坐标
#endif

    UNITY_VERTEX_OUTPUT_STEREO // 立体渲染时的左右眼索引，UnityInstancing.cginc
};

// UNIFORM_REFLECTIVITY(): workaround to get (uniform) reflecivity based on UNITY_SETUP_BRDF_INPUT
half MetallicSetup_Reflectivity() // 基于金属流的反射计算函数，Standard
{
    return 1.0h - OneMinusReflectivityFromMetallic(_Metallic);    // UnityStandardUtils.cginc L35
}

half SpecularSetup_Reflectivity()   // 基于镜面高光的反射计算函数，Standard Specular
{
    return SpecularStrength(_SpecColor.rgb);    // 直接返回高光强度 UnityStandardUtils.cginc L11
}

half RoughnessSetup_Reflectivity()  // 基于粗糙度，现在已变成了基于金属流
{
    return MetallicSetup_Reflectivity();
}

#define JOIN2(a, b) a##b
#define JOIN(a, b) JOIN2(a,b)
#define UNIFORM_REFLECTIVITY JOIN(UNITY_SETUP_BRDF_INPUT, _Reflectivity)    // 反射计算函数分流


#ifdef _NORMALMAP
// 将方向转换到切换空间
half3 TransformToTangentSpace(half3 tangent, half3 binormal, half3 normal, half3 v)
{
    // Mali400 shader compiler prefers explicit dot product over using a half3x3 matrix
    return half3(dot(tangent, v), dot(binormal, v), dot(normal, v));
}
// 在切线空间中计算光照
void TangentSpaceLightingInput(half3 normalWorld, half4 vTangent, half3 lightDirWorld, half3 eyeVecWorld, out half3 tangentSpaceLightDir, out half3 tangentSpaceEyeVec)
{ // normalWorld：世界空间中法线方向，vTangent：切线值，lightDirWorld：世界空间的光照方向，eyeVecWorld：世界空间的观察方向，tangentSpaceLightDir：切线空间的光照方向，tangentSpaceEyeVec：切线空间的观察方向
    half3 tangentWorld = UnityObjectToWorldDir(vTangent.xyz); // 切线方向转换到空间空间
    half sign = half(vTangent.w) * half(unity_WorldTransformParams.w); // 切线方向的符号，unity_WorldTransformParams.w标识左手坐标系(OpenGL)还是右手坐标系(DX)
    half3 binormalWorld = cross(normalWorld, tangentWorld) * sign; // 法线叉乘切线得到副法线
    tangentSpaceLightDir = TransformToTangentSpace(tangentWorld, binormalWorld, normalWorld, lightDirWorld); // 由法线、切线、副法线为基计算切线空间下的光照方向
    #if SPECULAR_HIGHLIGHTS // 如果开启了镜面高光反射，计算切线空间的观察方向
        tangentSpaceEyeVec = normalize(TransformToTangentSpace(tangentWorld, binormalWorld, normalWorld, eyeVecWorld));
    #else
        tangentSpaceEyeVec = 0;
    #endif
}

#endif // _NORMALMAP

VertexOutputBaseSimple vertForwardBaseSimple (VertexInput v)
{
    UNITY_SETUP_INSTANCE_ID(v); // 设置顶点的instance id
    VertexOutputBaseSimple o; // 声明输出结构体
    UNITY_INITIALIZE_OUTPUT(VertexOutputBaseSimple, o); // 清0
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);   // 声明立体沉浸时用到的左右眼索引

    float4 posWorld = mul(unity_ObjectToWorld, v.vertex);   // 把顶点从模型空间转换到世界空间
    o.pos = UnityObjectToClipPos(v.vertex); // 裁剪空间的位置
    o.tex = TexCoords(v);   // 设置第一层纹理映射坐标，UnityStandardInput.cginc

    half3 eyeVec = normalize(posWorld.xyz - _WorldSpaceCameraPos); // 观察方向
    half3 normalWorld = UnityObjectToWorldNormal(v.normal); // 当前顶点的法线方向

    o.normalWorld.xyz = normalWorld;
    o.eyeVec.xyz = eyeVec;

    #ifdef _NORMALMAP // 在切线空间中计算光照
        half3 tangentSpaceEyeVec;
        TangentSpaceLightingInput(normalWorld, v.tangent, _WorldSpaceLightPos0.xyz, eyeVec, o.tangentSpaceLightDir, tangentSpaceEyeVec);
        #if SPECULAR_HIGHLIGHTS
            o.tangentSpaceEyeVec = tangentSpaceEyeVec;
        #endif
    #endif

    //We need this for shadow receiving
    TRANSFER_SHADOW(o); // 将阴影坐标转换到各个空间下

    o.ambientOrLightmapUV = VertexGIForward(v, posWorld, normalWorld);  // 计算光照贴图的uv或者环境光照的强度，UnityStandardCore.cginc，L327

    o.fogCoord.yzw = reflect(eyeVec, normalWorld);  // 观察方向的反射方向，用于雾效uv计算

    o.normalWorld.w = Pow4(1 - saturate(dot(normalWorld, -eyeVec))); // fresnel term，菲涅尔的近似计算，（1 - 入射度与法线点乘）的4次方
    #if !GLOSSMAP // 如果光泽度纹理未被启用
        o.eyeVec.w = saturate(_Glossiness + UNIFORM_REFLECTIVITY()); // grazing term，使用光泽度和反射值的和对菲涅尔方程做一个调制，用来计算物体之间的间接照明的镜面高光
    #endif

    UNITY_TRANSFER_FOG(o, o.pos);   // 根据顶点的位置计算雾化因子
    return o;
}

// 初始化片元数据结构体， UnityStandardCore.cginc
FragmentCommonData FragmentSetupSimple(VertexOutputBaseSimple i)
{
    half alpha = Alpha(i.tex.xy);   // 得到当前的alpha值，UnityStandardInput.cginc，L110
    #if defined(_ALPHATEST_ON) // 如果开启了alpha test
        clip (alpha - _Cutoff); // 进行alpha test，如果被裁剪，则下面的计算都不需要再进行了
    #endif

    FragmentCommonData s = UNITY_SETUP_BRDF_INPUT (i.tex); // 根据PRR的工作流，装载对应的BRDF函数，MetallicSetup/SepcularSetup

    // NOTE: shader relies on pre-multiply alpha-blend (_SrcBlend = One, _DstBlend = OneMinusSrcAlpha)
    s.diffColor = PreMultiplyAlpha (s.diffColor, alpha, s.oneMinusReflectivity, /*out*/ s.alpha);   // 漫反射预乘alpha，交根据材质的金属性对alpha进行处理，UnityStandardUtils.cginc，L53

    s.normalWorld = i.normalWorld.xyz; // 世界空间的法向量
    s.eyeVec = i.eyeVec.xyz;    // 世界空间的观察向量
    s.posWorld = IN_WORLDPOS(i); // 世界空间的位置，UnityStandardCore.cginc, L 149
    s.reflUVW = i.fogCoord.yzw; // 反射向量

    #ifdef _NORMALMAP   // 如果开启了法线贴图
        s.tangentSpaceNormal =  NormalInTangentSpace(i.tex); // 切线空间的法向量，UnityStandardInput.cginc, L203
    #else
        s.tangentSpaceNormal =  0;
    #endif

    return s;
}
// 获取主光数据
UnityLight MainLightSimple(VertexOutputBaseSimple i, FragmentCommonData s)
{
    UnityLight mainLight = MainLight();     // UnityLightingCommon.cginc, L9，UnityStandardCore.cginc,L39
    return mainLight; // 颜色、方向、NdotL
}
// 获取掠射角系数
half PerVertexGrazingTerm(VertexOutputBaseSimple i, FragmentCommonData s)
{
    #if GLOSSMAP
        return saturate(s.smoothness + (1-s.oneMinusReflectivity));
    #else
        return i.eyeVec.w;
    #endif
}
// 获取菲涅尔系数
half PerVertexFresnelTerm(VertexOutputBaseSimple i)
{
    return i.normalWorld.w;
}
// 观察向量的反射向量
#if !SPECULAR_HIGHLIGHTS    // 如果反射高光未开启，则不计算反射向量
#   define REFLECTVEC_FOR_SPECULAR(i, s) half3(0, 0, 0)
#elif defined(_NORMALMAP)   // 如果开始了法线贴图，则在切线空间中计算反射向量
#   define REFLECTVEC_FOR_SPECULAR(i, s) reflect(i.tangentSpaceEyeVec, s.tangentSpaceNormal)
#else // 如果没有使用法线贴图，则使用顶点着色器计算的反射向量
#   define REFLECTVEC_FOR_SPECULAR(i, s) s.reflUVW
#endif
// 计算主光源的光照方向
half3 LightDirForSpecular(VertexOutputBaseSimple i, UnityLight mainLight)
{
    #if SPECULAR_HIGHLIGHTS && defined(_NORMALMAP) // 如果开启了镜面高光反射和法线贴图
        return i.tangentSpaceLightDir;  // 返回切线空间的光照方向
    #else // 否则返回世界空间的光照方向
        return mainLight.dir;
    #endif
}
// 计算简单直接光照的BRDF3
half3 BRDF3DirectSimple(half3 diffColor, half3 specColor, half smoothness, half rl)
{
    #if SPECULAR_HIGHLIGHTS
        return BRDF3_Direct(diffColor, specColor, Pow4(rl), smoothness);    // UnityStandardBRDF.cginc, L413
    #else
        return diffColor;
    #endif
}
// 片元着色器前向渲染路径的简单版本
half4 fragForwardBaseSimpleInternal (VertexOutputBaseSimple i)
{
    UNITY_APPLY_DITHER_CROSSFADE(i.pos.xy); // 如果定义了LOD淡入淡出，则使用Dither算法进行Fade

    FragmentCommonData s = FragmentSetupSimple(i); // 初始化片元数据结构体

    UnityLight mainLight = MainLightSimple(i, s);   // 声明主光结构体

    #if !defined(LIGHTMAP_ON) && defined(_NORMALMAP) // 如果没有开启光照贴图，并且有法线贴图
    half ndotl = saturate(dot(s.tangentSpaceNormal, i.tangentSpaceLightDir));   // 使用计算法线贴图后的法向量进行NdotL计算
    #else // 没有法线贴图
    half ndotl = saturate(dot(s.normalWorld, mainLight.dir)); // 使用世界空间的法向量进行NdotL计算
    #endif

    //we can't have worldpos here (not enough interpolator on SM 2.0) so no shadow fade in that case.
    half shadowMaskAttenuation = UnitySampleBakedOcclusion(i.ambientOrLightmapUV, 0); //计算使用烘焙模式生成的阴影衰减值，UnityShadowLibrary.cginc,L192
    half realtimeShadowAttenuation = SHADOW_ATTENUATION(i); // 计算实时模式的阴影衰减值，AutoLight.cginc，平行光L52
    half atten = UnityMixRealtimeAndBakedShadows(realtimeShadowAttenuation, shadowMaskAttenuation, 0);  // 混合烘焙、实时模式的阴影衰减值, UnityShadowLibrary.cginc,L254

    half occlusion = Occlusion(i.tex.xy); // 计算AO系数
    half rl = dot(REFLECTVEC_FOR_SPECULAR(i, s), LightDirForSpecular(i, mainLight)); // 计算高光反射项的入射光线和高光反射后的出射光线方向夹角的余弦

    UnityGI gi = FragmentGI (s, occlusion, i.ambientOrLightmapUV, atten, mainLight); // 计算全局光照， UnityStandardCore.cginc, L266
    half3 attenuatedLightColor = gi.light.color * ndotl; // 衰减后的光源颜色
    // 
    half3 c = BRDF3_Indirect(s.diffColor, s.specColor, gi.indirect, PerVertexGrazingTerm(i, s), PerVertexFresnelTerm(i)); // 计算间接光照的BRDF3, UnityStandardBRDF.cginc, L425
    c += BRDF3DirectSimple(s.diffColor, s.specColor, s.smoothness, rl) * attenuatedLightColor; // 计算简单直接光照的BRDF3
    c += Emission(i.tex.xy);    // 计算自发光颜色，UnityStandardInput.cginc, L193

    UNITY_APPLY_FOG(i.fogCoord, c); // 计算雾效，UnityCG.cginc, L1051

    return OutputForward (half4(c, 1), s.alpha); // 混合颜色和alpha，UnityStandardCore.cginc, L317
}
// 绑定的简单片元计算函数
half4 fragForwardBaseSimple (VertexOutputBaseSimple i) : SV_Target  // backward compatibility (this used to be the fragment entry function)
{
    return fragForwardBaseSimpleInternal(i);
}
// 顶点着色器 简单 前向点光源渲染路径数据结构体
struct VertexOutputForwardAddSimple
{
    UNITY_POSITION(pos);  // float4 pos : SV_POSITION
    float4 tex                          : TEXCOORD0;    // 顶点的第一层纹理坐标
    float3 posWorld                     : TEXCOORD1;    // 世界空间中下的位置

#if !defined(_NORMALMAP) && SPECULAR_HIGHLIGHTS // 如果没有开启法线贴图，并且开启了镜面高光反射
    UNITY_FOG_COORDS_PACKED(2, half4) // x: fogCoord, yzw: reflectVec，x：雾效因子，yzw，反射向量
#else
    UNITY_FOG_COORDS_PACKED(2, half1)   // 不开启镜面反射，或者使用了法线纹理（片元中计算），只有x雾效因子
#endif

    half3 lightDir                      : TEXCOORD3;    // 世界空间中的光照方向

#if defined(_NORMALMAP) // 如果使用了法线纹理贴图
    #if SPECULAR_HIGHLIGHTS // 如果开启镜面高光反射
        half3 tangentSpaceEyeVec        : TEXCOORD4;    // 需要计算切线空间基
    #endif
#else // 不使用法线纹理贴图
    half3 normalWorld                   : TEXCOORD4;    // 顶点法向量
#endif

    UNITY_LIGHTING_COORDS(5, 6) // 声明阴影纹理坐标，AutoLight.cginc, L294

    UNITY_VERTEX_OUTPUT_STEREO  // 立体渲染的左右眼索引，UnityInstancing.cginc, L109
};
// 简单前向点光源渲染路径的顶点着色器计算函数
VertexOutputForwardAddSimple vertForwardAddSimple (VertexInput v)
{
    VertexOutputForwardAddSimple o; // 声明数据
    UNITY_SETUP_INSTANCE_ID(v); // 设置顶点的 instance id
    UNITY_INITIALIZE_OUTPUT(VertexOutputForwardAddSimple, o);   // 数据清零
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);   // 初始化数据中立体渲染的部分

    float4 posWorld = mul(unity_ObjectToWorld, v.vertex);   // 顶点坐标模型空间转世界空间
    o.pos = UnityObjectToClipPos(v.vertex); // 转换到裁剪空间
    o.tex = TexCoords(v);   // 纹理坐标
    o.posWorld = posWorld.xyz;

    //We need this for shadow receiving and lighting
    UNITY_TRANSFER_LIGHTING(o, v.uv1);  // 计算阴影贴图坐标，AutoLight.cginc, L296

    half3 lightDir = _WorldSpaceLightPos0.xyz - posWorld.xyz * _WorldSpaceLightPos0.w;  // 光照方向，方向光w分量为1，点光为0
    #ifndef USING_DIRECTIONAL_LIGHT // 如果没有定义方向光
        lightDir = NormalizePerVertexNormal(lightDir);  // 光照方向归一化
    #endif

    #if SPECULAR_HIGHLIGHTS // 如果开启了镜面高光反射
        half3 eyeVec = normalize(posWorld.xyz - _WorldSpaceCameraPos);  // 计算归一化的观察方向
    #endif

    half3 normalWorld = UnityObjectToWorldNormal(v.normal); // 计算世界空间中的法向量

    #ifdef _NORMALMAP   // 如果使用了法线纹理贴图
        #if SPECULAR_HIGHLIGHTS // 如果使用了镜面高光反射，保存切线空间的观察向量
            TangentSpaceLightingInput(normalWorld, v.tangent, lightDir, eyeVec, o.lightDir, o.tangentSpaceEyeVec);  // 计算切线空间基
        #else // 否则，丢失观察向量
            half3 ignore;
            TangentSpaceLightingInput(normalWorld, v.tangent, lightDir, 0, o.lightDir, ignore);  // 计算切线空间基
        #endif
    #else // 如果没有使用法线纹理贴图
        o.lightDir = lightDir;  // 设置光照方向
        o.normalWorld = normalWorld;    // 设置顶点法线向量
        #if SPECULAR_HIGHLIGHTS // 如果开启了镜面高光反射
            o.fogCoord.yzw = reflect(eyeVec, normalWorld);  // 计算观察向量的反射向量
        #endif
    #endif

    UNITY_TRANSFER_FOG(o,o.pos);    // 计算雾效因子
    return o;
}
// 初始化简单前向点光源渲染路径的片元着色器数据
FragmentCommonData FragmentSetupSimpleAdd(VertexOutputForwardAddSimple i)
{
    half alpha = Alpha(i.tex.xy);   // 计算alpha
    #if defined(_ALPHATEST_ON)  // alpha test
        clip (alpha - _Cutoff);
    #endif

    FragmentCommonData s = UNITY_SETUP_BRDF_INPUT (i.tex);   // 根据PRR的工作流，装载对应的BRDF函数，MetallicSetup/SepcularSetup

    // NOTE: shader relies on pre-multiply alpha-blend (_SrcBlend = One, _DstBlend = OneMinusSrcAlpha)
    s.diffColor = PreMultiplyAlpha (s.diffColor, alpha, s.oneMinusReflectivity, /*out*/ s.alpha);   // 预乘alpha

    s.eyeVec = 0;
    s.posWorld = i.posWorld;

    #ifdef _NORMALMAP // 如果使用了法线纹理贴图
        s.tangentSpaceNormal = NormalInTangentSpace(i.tex); // 切线空间的法向量，UnityStandardInput.cginc, L203
        s.normalWorld = 0;
    #else // 否则使用顶点法向量
        s.tangentSpaceNormal = 0;
        s.normalWorld = i.normalWorld;
    #endif

    #if SPECULAR_HIGHLIGHTS && !defined(_NORMALMAP) // 如果开启了镜面高光反射，且没有使用法线贴图
        s.reflUVW = i.fogCoord.yzw;     // 使用顶点的反射向量
    #else
        s.reflUVW = 0;
    #endif

    return s;
}
// 获取法线
half3 LightSpaceNormal(VertexOutputForwardAddSimple i, FragmentCommonData s)
{
    #ifdef _NORMALMAP // 如果开启了法线纹理映射，则使用片元中的切线法线
        return s.tangentSpaceNormal;
    #else // 否则使用顶点法线
        return i.normalWorld;
    #endif
}
// 简单前向点光源渲染路径的片元着色器计算函数
half4 fragForwardAddSimpleInternal (VertexOutputForwardAddSimple i)
{
    UNITY_APPLY_DITHER_CROSSFADE(i.pos.xy); // 使用Dither算法进行LOD淡入淡出

    FragmentCommonData s = FragmentSetupSimpleAdd(i);   // 声明并初始化片元数据

    half3 c = BRDF3DirectSimple(s.diffColor, s.specColor, s.smoothness, dot(REFLECTVEC_FOR_SPECULAR(i, s), i.lightDir)); // 计算简单直接光照的BRDF3

    #if SPECULAR_HIGHLIGHTS // else diffColor has premultiplied light color
        c *= _LightColor0.rgb;  // 如果开启了高光，需要混合光照颜色，因为如果没有开启的话，漫反射颜色已经乘了光照颜色
    #endif

    UNITY_LIGHT_ATTENUATION(atten, i, s.posWorld)   // 计算光照强度衰减值
    c *= atten * saturate(dot(LightSpaceNormal(i, s), i.lightDir)); // 直接光照需要乘以（衰减值*反射强度）

    UNITY_APPLY_FOG_COLOR(i.fogCoord, c.rgb, half4(0,0,0,0)); // fog towards black in additive pass
    return OutputForward (half4(c, 1), s.alpha); // 混合颜色和alpha，UnityStandardCore.cginc, L317
}

half4 fragForwardAddSimple (VertexOutputForwardAddSimple i) : SV_Target // backward compatibility (this used to be the fragment entry function)
{
    return fragForwardAddSimpleInternal(i);
}

#endif // UNITY_STANDARD_CORE_FORWARD_SIMPLE_INCLUDED
