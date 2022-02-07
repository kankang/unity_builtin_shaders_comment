// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

#ifndef UNITY_STANDARD_CORE_INCLUDED
#define UNITY_STANDARD_CORE_INCLUDED

#include "UnityCG.cginc"
#include "UnityShaderVariables.cginc"
#include "UnityStandardConfig.cginc"
#include "UnityStandardInput.cginc"
#include "UnityPBSLighting.cginc"
#include "UnityStandardUtils.cginc"
#include "UnityGBuffer.cginc"
#include "UnityStandardBRDF.cginc"

#include "AutoLight.cginc"
//-------------------------------------------------------------------------------------
// counterpart for NormalizePerPixelNormal，在顶点着色器中归一化法向量
// skips normalization per-vertex and expects normalization to happen per-pixel
half3 NormalizePerVertexNormal (float3 n) // takes float to avoid overflow
{
    #if (SHADER_TARGET < 30) || UNITY_STANDARD_SIMPLE   // 如果小于Shader Model 3或者使用了简单着色器
        return normalize(n);    // 归一化
    #else   // 否则，不进行归一化（在片元中执行归一化）
        return n; // will normalize per-pixel instead
    #endif
}
// 在片元着色器中归一化法向量
float3 NormalizePerPixelNormal (float3 n)
{
    #if (SHADER_TARGET < 30) || UNITY_STANDARD_SIMPLE  // 如果小于Shader Model 3或者使用了简单着色器
        return n;
    #else  // 否则，进行归一化
        return normalize((float3)n); // takes float to avoid overflow
    #endif
}

//-------------------------------------------------------------------------------------
UnityLight MainLight () // 声明并返回一个UnityLight结构体
{
    UnityLight l; // 声明UnityLight

    l.color = _LightColor0.rgb;// 主光颜色
    l.dir = _WorldSpaceLightPos0.xyz;   // 主光方向
    return l;
}
// 声明并返回一个点光源结构体数据
UnityLight AdditiveLight (half3 lightDir, half atten)
{
    UnityLight l; // 声明UnityLight

    l.color = _LightColor0.rgb; // 光源颜色
    l.dir = lightDir;   // 光照方向
    #ifndef USING_DIRECTIONAL_LIGHT // 如果使用了方向光
        l.dir = NormalizePerPixelNormal(l.dir); // 进行归一化
    #endif

    // shadow the light
    l.color *= atten; // 最终颜色乘以衰减
    return l;
}
// 0直接光照，没有实际效果
UnityLight DummyLight ()
{
    UnityLight l;
    l.color = 0;
    l.dir = half3 (0,1,0);
    return l;
}
// 0间接光照
UnityIndirect ZeroIndirect ()
{
    UnityIndirect ind;
    ind.diffuse = 0;
    ind.specular = 0;
    return ind;
}

//-------------------------------------------------------------------------------------
// Common fragment setup

// deprecated
half3 WorldNormal(half4 tan2world[3])
{
    return normalize(tan2world[2].xyz);
}

// deprecated
#ifdef _TANGENT_TO_WORLD
    half3x3 ExtractTangentToWorldPerPixel(half4 tan2world[3])
    {
        half3 t = tan2world[0].xyz;
        half3 b = tan2world[1].xyz;
        half3 n = tan2world[2].xyz;

    #if UNITY_TANGENT_ORTHONORMALIZE
        n = NormalizePerPixelNormal(n);

        // ortho-normalize Tangent
        t = normalize (t - n * dot(t, n));

        // recalculate Binormal
        half3 newB = cross(n, t);
        b = newB * sign (dot (newB, b));
    #endif

        return half3x3(t, b, n);
    }
#else
    half3x3 ExtractTangentToWorldPerPixel(half4 tan2world[3])
    {
        return half3x3(0,0,0,0,0,0,0,0,0);
    }
#endif
// 计算片元的法线向量
float3 PerPixelWorldNormal(float4 i_tex, float4 tangentToWorld[3])
{
#ifdef _NORMALMAP   // 如果使用了法线纹理贴图
    half3 tangent = tangentToWorld[0].xyz;  // 切线基
    half3 binormal = tangentToWorld[1].xyz; // 副法线基
    half3 normal = tangentToWorld[2].xyz;   // 法线基

    #if UNITY_TANGENT_ORTHONORMALIZE    // 如果需要重新正交化切线空间基矩阵（默认关闭，UnityStandardConfig.cginc, L63
        normal = NormalizePerPixelNormal(normal);   // 归一化法线

        // ortho-normalize Tangent， 正交并归一化切线 
        tangent = normalize (tangent - normal * dot(tangent, normal));

        // recalculate Binormal，叉乘计算副法线
        half3 newB = cross(normal, tangent);
        binormal = newB * sign (dot (newB, binormal));  // 修正副法线方向
    #endif

    half3 normalTangent = NormalInTangentSpace(i_tex); // 计算法线纹理贴图中的法向量（切线空间） UnityStandardInput.cginc, L203
    float3 normalWorld = NormalizePerPixelNormal(tangent * normalTangent.x + binormal * normalTangent.y + normal * normalTangent.z); // @TODO: see if we can squeeze this normalize on SM2.0 as well
#else // 如果没有使用法线纹理贴图，则返回顶点的法向量
    float3 normalWorld = normalize(tangentToWorld[2].xyz);
#endif
    return normalWorld;
}

#ifdef _PARALLAXMAP // 如果开启了视差纹理贴图，则将切线空间中的观察方向作为视差纹理采样向量
    #define IN_VIEWDIR4PARALLAX(i) NormalizePerPixelNormal(half3(i.tangentToWorldAndPackedData[0].w,i.tangentToWorldAndPackedData[1].w,i.tangentToWorldAndPackedData[2].w))
    #define IN_VIEWDIR4PARALLAX_FWDADD(i) NormalizePerPixelNormal(i.viewDirForParallax.xyz)
#else // 否则不使用视差采样，方向归0
    #define IN_VIEWDIR4PARALLAX(i) half3(0,0,0)
    #define IN_VIEWDIR4PARALLAX_FWDADD(i) half3(0,0,0)
#endif
// 片面所在的世界空间的位置
#if UNITY_REQUIRE_FRAG_WORLDPOS // 如果开启了片面坐标
    #if UNITY_PACK_WORLDPOS_WITH_TANGENT // 如果使用了切线，则使用切线基矩阵的w
        #define IN_WORLDPOS(i) half3(i.tangentToWorldAndPackedData[0].w,i.tangentToWorldAndPackedData[1].w,i.tangentToWorldAndPackedData[2].w)
    #else // 否则使用顶点输入进行光栅化之后的坐标
        #define IN_WORLDPOS(i) i.posWorld
    #endif
    #define IN_WORLDPOS_FWDADD(i) i.posWorld // 前面附加渲染通过使用顶点坐标
#else // 否则全部归零
    #define IN_WORLDPOS(i) half3(0,0,0)
    #define IN_WORLDPOS_FWDADD(i) half3(0,0,0)
#endif

#define IN_LIGHTDIR_FWDADD(i) half3(i.tangentToWorldAndLightDir[0].w, i.tangentToWorldAndLightDir[1].w, i.tangentToWorldAndLightDir[2].w)
// 初始化前向渲染路径的片元数据
#define FRAGMENT_SETUP(x) FragmentCommonData x = \
    FragmentSetup(i.tex, i.eyeVec.xyz, IN_VIEWDIR4PARALLAX(i), i.tangentToWorldAndPackedData, IN_WORLDPOS(i));
// 初始化前向点光源渲染路径的片元数据
#define FRAGMENT_SETUP_FWDADD(x) FragmentCommonData x = \
    FragmentSetup(i.tex, i.eyeVec.xyz, IN_VIEWDIR4PARALLAX_FWDADD(i), i.tangentToWorldAndLightDir, IN_WORLDPOS_FWDADD(i));

struct FragmentCommonData   // 通过片元数据
{
    half3 diffColor, specColor; // 温反射颜色、镜面高光反射颜色
    // Note: smoothness & oneMinusReflectivity for optimization purposes, mostly for DX9 SM2.0 level.
    // Most of the math is being done on these (1-x) values, and that saves a few precious ALU slots.
    half oneMinusReflectivity, smoothness;  // 1-反射率，光滑度
    float3 normalWorld; // 世界空间中的法线向量
    float3 eyeVec;  // 世界空间中的观察向量
    half alpha; // 透明度
    float3 posWorld;    // 世界空间中的位置

#if UNITY_STANDARD_SIMPLE   // 如果是简化版
    half3 reflUVW; // 世界空间中的反射向量
#endif

#if UNITY_STANDARD_SIMPLE // 如果是简化版
    half3 tangentSpaceNormal;   // 切线空间的法线向量
#endif
};

#ifndef UNITY_SETUP_BRDF_INPUT  // 如果没有在shader中指定使用哪种PBR工作流
    #define UNITY_SETUP_BRDF_INPUT SpecularSetup    // 就使用镜面反射工作流
#endif
// 基于镜面高光反射工作流
inline FragmentCommonData SpecularSetup (float4 i_tex)
{
    half4 specGloss = SpecularGloss(i_tex.xy);  // 获取镜面高光反射颜色和光滑度
    half3 specColor = specGloss.rgb;
    half smoothness = specGloss.a;

    half oneMinusReflectivity; // 漫反射占比，镜面反射时，计算漫反射的保存度，通常解决漫反射+高光反射后，过亮的问题，UnityStandardUtils.cginc, L22
    half3 diffColor = EnergyConservationBetweenDiffuseAndSpecular (Albedo(i_tex), specColor, /*out*/ oneMinusReflectivity);

    FragmentCommonData o = (FragmentCommonData)0; // 声明并归零能用片面结构体
    o.diffColor = diffColor;
    o.specColor = specColor;
    o.oneMinusReflectivity = oneMinusReflectivity;
    o.smoothness = smoothness;
    return o;
}
// 基于粗糙度工作流，实质上是金属工作流
inline FragmentCommonData RoughnessSetup(float4 i_tex)
{
    half2 metallicGloss = MetallicRough(i_tex.xy);
    half metallic = metallicGloss.x;
    half smoothness = metallicGloss.y; // this is 1 minus the square root of real roughness m.

    half oneMinusReflectivity;
    half3 specColor;
    half3 diffColor = DiffuseAndSpecularFromMetallic(Albedo(i_tex), metallic, /*out*/ specColor, /*out*/ oneMinusReflectivity);

    FragmentCommonData o = (FragmentCommonData)0;
    o.diffColor = diffColor;
    o.specColor = specColor;
    o.oneMinusReflectivity = oneMinusReflectivity;
    o.smoothness = smoothness;
    return o;
}
// 基于金属工作流的PBR
inline FragmentCommonData MetallicSetup (float4 i_tex)
{
    half2 metallicGloss = MetallicGloss(i_tex.xy);  // 获取金属度和光滑度
    half metallic = metallicGloss.x;
    half smoothness = metallicGloss.y; // this is 1 minus the square root of real roughness m

    half oneMinusReflectivity;  // 1 - Cspec
    half3 specColor; // Cspec   F(h, wi) = Cspec + (1 - Cspec)*(1 - hwi)^5
    half3 diffColor = DiffuseAndSpecularFromMetallic (Albedo(i_tex), metallic, /*out*/ specColor, /*out*/ oneMinusReflectivity); // 计算漫反射颜色和镜面高光反射颜色，UnityStandardUtils.cginc, L46
    
    FragmentCommonData o = (FragmentCommonData)0; // 声明并归零能用片面结构体
    o.diffColor = diffColor;
    o.specColor = specColor;
    o.oneMinusReflectivity = oneMinusReflectivity;
    o.smoothness = smoothness;
    return o;
}
// 初始化片元数据
// parallax transformed texcoord is used to sample occlusion
inline FragmentCommonData FragmentSetup (inout float4 i_tex, float3 i_eyeVec, half3 i_viewDirForParallax, float4 tangentToWorld[3], float3 i_posWorld)
{ // i_tex：第一层纹理映射坐标；i_eyeVec：裁剪空间中的观察方向；i_viewDirForParallax：切线空间中的观察方向；tangentToWorld[3]：切线空间基矩阵；i_posWorld：世界坐标
    i_tex = Parallax(i_tex, i_viewDirForParallax); // 经过视差偏移后的纹理坐标，UnityStandardInput.cginc, L227

    half alpha = Alpha(i_tex.xy);   // 采样alpha值
    #if defined(_ALPHATEST_ON)  // 是否进行alphatest，要尽早做
        clip (alpha - _Cutoff);
    #endif

    FragmentCommonData o = UNITY_SETUP_BRDF_INPUT (i_tex);  // MetallicSetup
    o.normalWorld = PerPixelWorldNormal(i_tex, tangentToWorld); // 计算片面法向量
    o.eyeVec = NormalizePerPixelNormal(i_eyeVec);   // 归一化观察向量
    o.posWorld = i_posWorld;    // 设置顶点世界位置

    // NOTE: shader relies on pre-multiply alpha-blend (_SrcBlend = One, _DstBlend = OneMinusSrcAlpha)
    o.diffColor = PreMultiplyAlpha (o.diffColor, alpha, o.oneMinusReflectivity, /*out*/ o.alpha);   // 漫反射颜色预乘alpha
    return o;
}
// 计算全局光照，s通用片元数据；occlusion环境光遮挡；i_ambientOrLightmapUV环境光颜色或光贴图uv；atten阴影衰减；light直接光照；reflections是否开启反射
inline UnityGI FragmentGI (FragmentCommonData s, half occlusion, half4 i_ambientOrLightmapUV, half atten, UnityLight light, bool reflections)
{
    UnityGIInput d; // UnityLightingCommon.cginc,L28
    d.light = light;    // 记录要用来进行光照计算的光源颜色
    d.worldPos = s.posWorld;    // 记录世界空间中的位置
    d.worldViewDir = -s.eyeVec; // 记录世界空间中观察微量的反方向
    d.atten = atten;    // 记录光照强度衰减
    #if defined(LIGHTMAP_ON) || defined(DYNAMICLIGHTMAP_ON) // 如果开启了光贴图
        d.ambient = 0;  // 环境光颜色为0
        d.lightmapUV = i_ambientOrLightmapUV;   // 记录光贴图的uv
    #else   // 如果开启了实时光照
        d.ambient = i_ambientOrLightmapUV.rgb;  // 记录环境光颜色
        d.lightmapUV = 0;
    #endif
    // 记录两个反射用光探针的各项属性
    d.probeHDR[0] = unity_SpecCube0_HDR;    // HDR光照探针
    d.probeHDR[1] = unity_SpecCube1_HDR;    // HDR光照探针
    #if defined(UNITY_SPECCUBE_BLENDING) || defined(UNITY_SPECCUBE_BOX_PROJECTION)  // 光探针所占据空间包围盒范围的边界极小值
      d.boxMin[0] = unity_SpecCube0_BoxMin; // .w holds lerp value for blending
    #endif
    #ifdef UNITY_SPECCUBE_BOX_PROJECTION
      d.boxMax[0] = unity_SpecCube0_BoxMax;// 光探针所占据空间包围盒范围的边界极大值
      d.probePosition[0] = unity_SpecCube0_ProbePosition;    // 光探针位置
      d.boxMax[1] = unity_SpecCube1_BoxMax;
      d.boxMin[1] = unity_SpecCube1_BoxMin;
      d.probePosition[1] = unity_SpecCube1_ProbePosition;
    #endif

    if(reflections)
    { // 如果开启了反射
        Unity_GlossyEnvironmentData g = UnityGlossyEnvironmentSetup(s.smoothness, -s.eyeVec, s.normalWorld, s.specColor);
        // Replace the reflUVW if it has been compute in Vertex shader. Note: the compiler will optimize the calcul in UnityGlossyEnvironmentSetup itself
        #if UNITY_STANDARD_SIMPLE
            g.reflUVW = s.reflUVW;  // 使用顶点反射向量
        #endif

        return UnityGlobalIllumination (d, occlusion, s.normalWorld, g);    // 计算全局光照的漫反射，UnityGlobalIllumination,L197
    }
    else
    {
        return UnityGlobalIllumination (d, occlusion, s.normalWorld);    // 计算全局光照的漫反射，UnityGlobalIllumination,L202
    }
}
// 计算全局光照，默认开启反射
inline UnityGI FragmentGI (FragmentCommonData s, half occlusion, half4 i_ambientOrLightmapUV, half atten, UnityLight light)
{
    return FragmentGI(s, occlusion, i_ambientOrLightmapUV, atten, light, true);
}


//-------------------------------------------------------------------------------------
half4 OutputForward (half4 output, half alphaFromSurface) // 前向渲染路径的颜色输出
{
    #if defined(_ALPHABLEND_ON) || defined(_ALPHAPREMULTIPLY_ON)    // 如果开启了透明
        output.a = alphaFromSurface;    // 输出的alpha通道是通过表面计算出来的alpha
    #else // 否则就是不透明，alpha值为1
        UNITY_OPAQUE_ALPHA(output.a);
    #endif
    return output;
}
// 顶点着色器前向渲染的全局光照计算（烘焙光照返回Lightmap的uv，实时光照返回环境光强度）
inline half4 VertexGIForward(VertexInput v, float3 posWorld, half3 normalWorld)
{
    half4 ambientOrLightmapUV = 0;
    // Static lightmaps
    #ifdef LIGHTMAP_ON  // 使用光照贴图，返回光照贴图的uv的xy
        ambientOrLightmapUV.xy = v.uv1.xy * unity_LightmapST.xy + unity_LightmapST.zw;
        ambientOrLightmapUV.zw = 0;
    // Sample light probe for Dynamic objects only (no static or dynamic lightmaps)
    #elif UNITY_SHOULD_SAMPLE_SH    // 使用实时光照，球谐采样
        #ifdef VERTEXLIGHT_ON
            // Approximated illumination from non-important point lights，计算4个不重要的点光强度
            ambientOrLightmapUV.rgb = Shade4PointLights (
                unity_4LightPosX0, unity_4LightPosY0, unity_4LightPosZ0,
                unity_LightColor[0].rgb, unity_LightColor[1].rgb, unity_LightColor[2].rgb, unity_LightColor[3].rgb,
                unity_4LightAtten0, posWorld, normalWorld);
        #endif

        ambientOrLightmapUV.rgb = ShadeSHPerVertex (normalWorld, ambientOrLightmapUV.rgb);  // 环境光球谐采样
    #endif

    #ifdef DYNAMICLIGHTMAP_ON // 动态烘焙光照，设置光照贴图uv的zw
        ambientOrLightmapUV.zw = v.uv2.xy * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
    #endif

    return ambientOrLightmapUV;
}

// ------------------------------------------------------------------
//  Base forward pass (directional light, emission, lightmaps, ...)
// ========标准的前向渲染路径=========
struct VertexOutputForwardBase //标准前向渲染路径的结构体数据
{
    UNITY_POSITION(pos);    // float4 pos : SV_POSITION
    float4 tex                            : TEXCOORD0;    // 顶点的第一层纹理坐标
    float4 eyeVec                         : TEXCOORD1;    // eyeVec.xyz | fogCoord // 观察方向
    float4 tangentToWorldAndPackedData[3] : TEXCOORD2;    // [3x3:tangentToWorld | 1x3:viewDirForParallax or worldPos] 切线空间基
    half4 ambientOrLightmapUV             : TEXCOORD5;    // SH or Lightmap UV 环境光球谐颜色或者光贴图UV
    UNITY_LIGHTING_COORDS(6,7)  // 声明光照和阴影纹理坐标

    // next ones would not fit into SM2.0 limits, but they are always for SM3.0+
#if UNITY_REQUIRE_FRAG_WORLDPOS && !UNITY_PACK_WORLDPOS_WITH_TANGENT
    float3 posWorld                     : TEXCOORD8;   // 世界空间下的顶点坐标
#endif

    UNITY_VERTEX_INPUT_INSTANCE_ID // 顶点实例化渲染的id
    UNITY_VERTEX_OUTPUT_STEREO // 立体渲染时的左右眼索引，UnityInstancing.cginc
};
// 计算标准的顶点着色器前向渲染路径的数据
VertexOutputForwardBase vertForwardBase (VertexInput v)
{
    UNITY_SETUP_INSTANCE_ID(v); // 设置顶点的instance id
    VertexOutputForwardBase o; // 声明输出结构体
    UNITY_INITIALIZE_OUTPUT(VertexOutputForwardBase, o); // 清0
    UNITY_TRANSFER_INSTANCE_ID(v, o);   // 将输入VertexInput中的顶点isntance id转换到输出VertexOutputForwardBase中
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);   // 声明立体沉浸时用到的左右眼索引

    float4 posWorld = mul(unity_ObjectToWorld, v.vertex);   // 把顶点从模型空间转换到世界空间
    #if UNITY_REQUIRE_FRAG_WORLDPOS // 如果需要片元世界位置
        #if UNITY_PACK_WORLDPOS_WITH_TANGENT // 使用了切线空间基向量，将世界位置存入切线空间基微量的w分量中
            o.tangentToWorldAndPackedData[0].w = posWorld.x;
            o.tangentToWorldAndPackedData[1].w = posWorld.y;
            o.tangentToWorldAndPackedData[2].w = posWorld.z;
        #else // 否则直接设置世界坐标
            o.posWorld = posWorld.xyz;
        #endif
    #endif
    o.pos = UnityObjectToClipPos(v.vertex); // 模型空间变换至世界空间

    o.tex = TexCoords(v); // 设置第一层纹理映射坐标
    o.eyeVec.xyz = NormalizePerVertexNormal(posWorld.xyz - _WorldSpaceCameraPos);   // 观察方向（标准着色器的归一化在片元中处理）
    float3 normalWorld = UnityObjectToWorldNormal(v.normal);    // 法向量从模型空间变换到世界空间
    #ifdef _TANGENT_TO_WORLD    // 如果开启了切线空间
        float4 tangentWorld = float4(UnityObjectToWorldDir(v.tangent.xyz), v.tangent.w);    // 世界空间下的切线方向

        float3x3 tangentToWorld = CreateTangentToWorldPerVertex(normalWorld, tangentWorld.xyz, tangentWorld.w); // 构建切线空间矩阵，UnityStandardUtils.cginc, L149
        o.tangentToWorldAndPackedData[0].xyz = tangentToWorld[0];   // 切线基向量
        o.tangentToWorldAndPackedData[1].xyz = tangentToWorld[1];   // 副法线基向量
        o.tangentToWorldAndPackedData[2].xyz = tangentToWorld[2];   // 法线基向量
    #else
        o.tangentToWorldAndPackedData[0].xyz = 0;
        o.tangentToWorldAndPackedData[1].xyz = 0;
        o.tangentToWorldAndPackedData[2].xyz = normalWorld; // 只存储法线向量
    #endif

    //We need this for shadow receving
    UNITY_TRANSFER_LIGHTING(o, v.uv1);  // 将第二层纹理坐标转换成阴影因子

    o.ambientOrLightmapUV = VertexGIForward(v, posWorld, normalWorld);  // 计算全局光照

    #ifdef _PARALLAXMAP // 如果开启了视差纹理贴图
        TANGENT_SPACE_ROTATION; // 构建切线空间基
        half3 viewDirForParallax = mul (rotation, ObjSpaceViewDir(v.vertex));   // 计算视差纹理使用的观察方向，并存储在切线基的w分量
        o.tangentToWorldAndPackedData[0].w = viewDirForParallax.x;
        o.tangentToWorldAndPackedData[1].w = viewDirForParallax.y;
        o.tangentToWorldAndPackedData[2].w = viewDirForParallax.z;
    #endif

    UNITY_TRANSFER_FOG_COMBINED_WITH_EYE_VEC(o,o.pos);  // 计算雾效因子
    return o;
}
// 前向通路的标准版片元着色器入口函数
half4 fragForwardBaseInternal (VertexOutputForwardBase i)
{
    UNITY_APPLY_DITHER_CROSSFADE(i.pos.xy); // 使用Dither算法进行LOD淡入淡出

    FRAGMENT_SETUP(s)   // 初始化通用片元数据

    UNITY_SETUP_INSTANCE_ID(i); // 设置顶点的instance id
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);    // 设置立体渲染左右眼顶点的instance id

    UnityLight mainLight = MainLight ();   // 声明主光结构体
    UNITY_LIGHT_ATTENUATION(atten, i, s.posWorld);  // 计算光线强度衰减

    half occlusion = Occlusion(i.tex.xy); // 计算AO系数
    UnityGI gi = FragmentGI (s, occlusion, i.ambientOrLightmapUV, atten, mainLight); // 计算全局光照， UnityStandardCore.cginc, L266
    // 根据TireSetting.standardShaderQuality来设置BRDF PBS的等级，UnityPBSLighting.cginc, L14
    half4 c = UNITY_BRDF_PBS (s.diffColor, s.specColor, s.oneMinusReflectivity, s.smoothness, s.normalWorld, -s.eyeVec, gi.light, gi.indirect);
    c.rgb += Emission(i.tex.xy);    // 计算自发光颜色，UnityStandardInput.cginc, L193

    UNITY_EXTRACT_FOG_FROM_EYE_VEC(i);  // 雾效纹理坐标使用观察向量的w
    UNITY_APPLY_FOG(_unity_fogCoord, c.rgb); // 计算雾效，UnityCG.cginc, L1051
    return OutputForward (c, s.alpha); // 混合颜色和alpha，UnityStandardCore.cginc, L317
}

half4 fragForwardBase (VertexOutputForwardBase i) : SV_Target   // backward compatibility (this used to be the fragment entry function)
{
    return fragForwardBaseInternal(i);
}

// ------------------------------------------------------------------
//  Additive forward pass (one light per pass)，前向点光源渲染路径，每个点光源执行一次
// 顶点着色器 标准 前向点光源渲染路径数据结构体
struct VertexOutputForwardAdd
{
    UNITY_POSITION(pos);  // float4 pos : SV_POSITION
    float4 tex                          : TEXCOORD0;    // 顶点的第一层纹理坐标
    float4 eyeVec                       : TEXCOORD1;    // eyeVec.xyz | fogCoord，雾效因子或者反射向量
    float4 tangentToWorldAndLightDir[3] : TEXCOORD2;    // [3x3:tangentToWorld | 1x3:lightDir]  // 切线空间基或光照方向
    float3 posWorld                     : TEXCOORD5;    // 世界空间中下的位置
    UNITY_LIGHTING_COORDS(6, 7)                         // 声明阴影纹理坐标，AutoLight.cginc, L294

    // next ones would not fit into SM2.0 limits, but they are always for SM3.0+
#if defined(_PARALLAXMAP)   // 如果开启了视差纹理贴图
    half3 viewDirForParallax            : TEXCOORD8;    // 用于视差偏移计算的观察方向
#endif

    UNITY_VERTEX_OUTPUT_STEREO  // 立体渲染的左右眼索引，UnityInstancing.cginc, L109
};
// 标准前向点光源渲染路径的顶点着色器计算函数
VertexOutputForwardAdd vertForwardAdd (VertexInput v)
{
    UNITY_SETUP_INSTANCE_ID(v); // 设置顶点的 instance id
    VertexOutputForwardAdd o;   // 声明数据
    UNITY_INITIALIZE_OUTPUT(VertexOutputForwardAdd, o);   // 数据清零
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);   // 初始化数据中立体渲染的部分

    float4 posWorld = mul(unity_ObjectToWorld, v.vertex);   // 顶点坐标模型空间转世界空间
    o.pos = UnityObjectToClipPos(v.vertex); // 转换到裁剪空间

    o.tex = TexCoords(v);   // 纹理坐标
    o.eyeVec.xyz = NormalizePerVertexNormal(posWorld.xyz - _WorldSpaceCameraPos);   // 计算归一化的观察向量
    o.posWorld = posWorld.xyz;
    float3 normalWorld = UnityObjectToWorldNormal(v.normal);    // 法向量从模型空间变换到世界空间
    #ifdef _TANGENT_TO_WORLD    // 如果开启了切线空间
        float4 tangentWorld = float4(UnityObjectToWorldDir(v.tangent.xyz), v.tangent.w);    // 世界空间下的切线方向

        float3x3 tangentToWorld = CreateTangentToWorldPerVertex(normalWorld, tangentWorld.xyz, tangentWorld.w);
        o.tangentToWorldAndLightDir[0].xyz = tangentToWorld[0]; // 切线基向量
        o.tangentToWorldAndLightDir[1].xyz = tangentToWorld[1]; // 副法线基向量
        o.tangentToWorldAndLightDir[2].xyz = tangentToWorld[2]; // 法线基向量
    #else
        o.tangentToWorldAndLightDir[0].xyz = 0;
        o.tangentToWorldAndLightDir[1].xyz = 0;
        o.tangentToWorldAndLightDir[2].xyz = normalWorld; // 只存储法线向量
    #endif
    //We need this for shadow receiving and lighting
    UNITY_TRANSFER_LIGHTING(o, v.uv1);  // 将第二层纹理坐标转换成阴影因子

    float3 lightDir = _WorldSpaceLightPos0.xyz - posWorld.xyz * _WorldSpaceLightPos0.w; // 光照方向
    #ifndef USING_DIRECTIONAL_LIGHT
        lightDir = NormalizePerVertexNormal(lightDir);  // 如果是方向光，归一化
    #endif
    o.tangentToWorldAndLightDir[0].w = lightDir.x;  // 将光照方向写入切线矩阵的w分量
    o.tangentToWorldAndLightDir[1].w = lightDir.y;
    o.tangentToWorldAndLightDir[2].w = lightDir.z;

    #ifdef _PARALLAXMAP // 如果开启了视差纹理贴图
        TANGENT_SPACE_ROTATION; // 构建切线空间基
        o.viewDirForParallax = mul (rotation, ObjSpaceViewDir(v.vertex));   // 计算视差纹理使用的观察方向
    #endif

    UNITY_TRANSFER_FOG_COMBINED_WITH_EYE_VEC(o, o.pos);  // 计算雾效因子
    return o;
}
// 标准前向点光源渲染路径的片元着色器计算函数
half4 fragForwardAddInternal (VertexOutputForwardAdd i)
{
    UNITY_APPLY_DITHER_CROSSFADE(i.pos.xy); // 使用Dither算法进行LOD淡入淡出

    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);    // 设置立体渲染左右眼顶点的instance id

    FRAGMENT_SETUP_FWDADD(s)    // 初始化前向点光源渲染路径的片元数据

    UNITY_LIGHT_ATTENUATION(atten, i, s.posWorld)  // 计算光线强度衰减
    UnityLight light = AdditiveLight (IN_LIGHTDIR_FWDADD(i), atten);    // 计算直接光照
    UnityIndirect noIndirect = ZeroIndirect (); // 使用0间接光照
    // 根据TireSetting.standardShaderQuality来设置BRDF PBS的等级，UnityPBSLighting.cginc, L14
    half4 c = UNITY_BRDF_PBS (s.diffColor, s.specColor, s.oneMinusReflectivity, s.smoothness, s.normalWorld, -s.eyeVec, light, noIndirect);

    UNITY_EXTRACT_FOG_FROM_EYE_VEC(i);  // 雾效纹理坐标使用观察向量的w
    UNITY_APPLY_FOG_COLOR(_unity_fogCoord, c.rgb, half4(0,0,0,0)); // fog towards black in additive pass // 计算雾效（颜色为黑），UnityCG.cginc, L1051
    return OutputForward (c, s.alpha); // 混合颜色和alpha，UnityStandardCore.cginc, L317
}

half4 fragForwardAdd (VertexOutputForwardAdd i) : SV_Target     // backward compatibility (this used to be the fragment entry function)
{
    return fragForwardAddInternal(i);
}

// ------------------------------------------------------------------
//  Deferred pass 延迟渲染路径
// 延迟渲染顶点着色器输出结构体
struct VertexOutputDeferred
{
    UNITY_POSITION(pos);    // float4 pos : SV_POSITION
    float4 tex                            : TEXCOORD0;  // 第一层纹理坐标
    float3 eyeVec                         : TEXCOORD1;  // 观察方向
    float4 tangentToWorldAndPackedData[3] : TEXCOORD2;    // [3x3:tangentToWorld | 1x3:viewDirForParallax or worldPos]  // 切线空间基向量
    half4 ambientOrLightmapUV             : TEXCOORD5;    // SH or Lightmap UVs 球谐参数或者光贴图纹理坐标

    #if UNITY_REQUIRE_FRAG_WORLDPOS && !UNITY_PACK_WORLDPOS_WITH_TANGENT
        float3 posWorld                     : TEXCOORD6;    // 世界空间位置
    #endif

    UNITY_VERTEX_INPUT_INSTANCE_ID // 顶点实例化渲染的id
    UNITY_VERTEX_OUTPUT_STEREO // 立体渲染时的左右眼索引，UnityInstancing.cginc
};

// 延迟渲染路径顶点着色器函数
VertexOutputDeferred vertDeferred (VertexInput v)
{
    UNITY_SETUP_INSTANCE_ID(v);     // 设置顶点的instance id
    VertexOutputDeferred o;
    UNITY_INITIALIZE_OUTPUT(VertexOutputDeferred, o);   // 初始化结构体
    UNITY_TRANSFER_INSTANCE_ID(v, o);   // 将输入VertexInput中的顶点isntance id转换到输出VertexOutputForwardBase中
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);   // 声明立体沉浸时用到的左右眼索引

    float4 posWorld = mul(unity_ObjectToWorld, v.vertex);   // 模型空间转世界空间
    #if UNITY_REQUIRE_FRAG_WORLDPOS
        #if UNITY_PACK_WORLDPOS_WITH_TANGENT    // 如果使用切线空间，将世界坐标存入切线空间基向量的w中
            o.tangentToWorldAndPackedData[0].w = posWorld.x;
            o.tangentToWorldAndPackedData[1].w = posWorld.y;
            o.tangentToWorldAndPackedData[2].w = posWorld.z;
        #else // 否则就赋值给结构体
            o.posWorld = posWorld.xyz;
        #endif
    #endif
    o.pos = UnityObjectToClipPos(v.vertex); // 模型空间转裁剪空间

    o.tex = TexCoords(v);   // 第一层纹理坐标
    o.eyeVec = NormalizePerVertexNormal(posWorld.xyz - _WorldSpaceCameraPos);   // 归一化观察方向
    float3 normalWorld = UnityObjectToWorldNormal(v.normal);    // 世界空间中的法向量
    #ifdef _TANGENT_TO_WORLD
        float4 tangentWorld = float4(UnityObjectToWorldDir(v.tangent.xyz), v.tangent.w);    // 如果开启了切线空间

        float3x3 tangentToWorld = CreateTangentToWorldPerVertex(normalWorld, tangentWorld.xyz, tangentWorld.w);
        o.tangentToWorldAndPackedData[0].xyz = tangentToWorld[0];   // 切线基向量
        o.tangentToWorldAndPackedData[1].xyz = tangentToWorld[1];   // 副法线基向量
        o.tangentToWorldAndPackedData[2].xyz = tangentToWorld[2];   // 法线基向量
    #else
        o.tangentToWorldAndPackedData[0].xyz = 0;
        o.tangentToWorldAndPackedData[1].xyz = 0;
        o.tangentToWorldAndPackedData[2].xyz = normalWorld; // 只存储法线向量
    #endif

    o.ambientOrLightmapUV = 0;
    #ifdef LIGHTMAP_ON  // 如果使用了光照纹理贴图，设置光照贴图uv的xy
        o.ambientOrLightmapUV.xy = v.uv1.xy * unity_LightmapST.xy + unity_LightmapST.zw;    // 
    #elif UNITY_SHOULD_SAMPLE_SH // 否则ambientOrLightmapUV装入环境光颜色
        o.ambientOrLightmapUV.rgb = ShadeSHPerVertex (normalWorld, o.ambientOrLightmapUV.rgb);  // 环境光球谐采样
    #endif
    #ifdef DYNAMICLIGHTMAP_ON // 动态烘焙光照，设置光照贴图uv的zw
        o.ambientOrLightmapUV.zw = v.uv2.xy * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;  // 
    #endif

    #ifdef _PARALLAXMAP // 如果开启了视差纹理贴图
        TANGENT_SPACE_ROTATION; // 构建切线空间基
        half3 viewDirForParallax = mul (rotation, ObjSpaceViewDir(v.vertex));   // 计算视差纹理使用的观察方向，并存储在切线基的w分量
        o.tangentToWorldAndPackedData[0].w = viewDirForParallax.x;
        o.tangentToWorldAndPackedData[1].w = viewDirForParallax.y;
        o.tangentToWorldAndPackedData[2].w = viewDirForParallax.z;
    #endif

    return o;
}
// 延迟渲染路径片元着色器函数
void fragDeferred (
    VertexOutputDeferred i,        // 顶点着色器输入
    out half4 outGBuffer0 : SV_Target0, // RGB存储片元的漫反射BRDF值，A存储片元的遮蔽值
    out half4 outGBuffer1 : SV_Target1, // RGB存储片元的镜面高光BRDF值，A存储片元的粗糙度值
    out half4 outGBuffer2 : SV_Target2, // RGB存储片元的基于世界坐标系的宏观法线方向，A未被使用
    out half4 outEmission : SV_Target3          // RT3: emission (rgb), --unused-- (a)  // RGB存储自发光颜色，A未被使用
#if defined(SHADOWS_SHADOWMASK) && (UNITY_ALLOWED_MRT_COUNT > 4)
    ,out half4 outShadowMask : SV_Target4       // RT4: shadowmask (rgba)   // 存储片元的阴影蒙版值
#endif
)
{
    #if (SHADER_TARGET < 30)    // 如果小于Shader Model 3，则不支持延迟渲染
        outGBuffer0 = 1;
        outGBuffer1 = 1;
        outGBuffer2 = 0;
        outEmission = 0;
        #if defined(SHADOWS_SHADOWMASK) && (UNITY_ALLOWED_MRT_COUNT > 4)
            outShadowMask = 1;
        #endif
        return;
    #endif

    UNITY_APPLY_DITHER_CROSSFADE(i.pos.xy); // 使用Dither算法进行淡入淡出

    FRAGMENT_SETUP(s)// 初始化前向点光源渲染路径的片元数据
    UNITY_SETUP_INSTANCE_ID(i); // 设置instance id

    // no analytic lights in this pass
    UnityLight dummyLight = DummyLight ();  // 延迟渲染路径，在最后才执行一个可见片元的光照计算
    half atten = 1;

    // only GI，只做全局光照
    half occlusion = Occlusion(i.tex.xy);   // 环境光遮蔽
#if UNITY_ENABLE_REFLECTION_BUFFERS
    bool sampleReflectionsInDeferred = false;
#else
    bool sampleReflectionsInDeferred = true;
#endif

    UnityGI gi = FragmentGI (s, occlusion, i.ambientOrLightmapUV, atten, dummyLight, sampleReflectionsInDeferred); // 计算全局光照， UnityStandardCore.cginc, L266
    // 由于没有颜色光线，所以通过BRDF函数只能得到漫反射颜色+镜面高光反射颜色，所以命名为emissive放射光
    half3 emissiveColor = UNITY_BRDF_PBS (s.diffColor, s.specColor, s.oneMinusReflectivity, s.smoothness, s.normalWorld, -s.eyeVec, gi.light, gi.indirect).rgb;

    #ifdef _EMISSION
        emissiveColor += Emission (i.tex.xy);   // 叠加自发光颜色
    #endif

    #ifndef UNITY_HDR_ON // 如果使用了HDR，就对颜色进行调制
        emissiveColor.rgb = exp2(-emissiveColor.rgb);
    #endif

    UnityStandardData data; // Unity标准数据
    data.diffuseColor   = s.diffColor;  // 记录片元漫反射部分的BRDF值
    data.occlusion      = occlusion;    // 记录片元的AO系数
    data.specularColor  = s.specColor;  // 记录片元镜面高光反射部分的BRDF值
    data.smoothness     = s.smoothness; // 记录片元的光滑度值
    data.normalWorld    = s.normalWorld;    // 记录片元的法向量

    UnityStandardDataToGbuffer(data, outGBuffer0, outGBuffer1, outGBuffer2);    // 写入Gbuffer, UnityGBuffer.cginc, L21

    // Emissive lighting buffer
    outEmission = half4(emissiveColor, 1);  // 设置输出的放射光颜色

    // Baked direct lighting occlusion if any
    #if defined(SHADOWS_SHADOWMASK) && (UNITY_ALLOWED_MRT_COUNT > 4)
        outShadowMask = UnityGetRawBakedOcclusions(i.ambientOrLightmapUV.xy, IN_WORLDPOS(i));   // 计算阴影蒙版值，UnityShadowLibrary.cginc, L232
    #endif
}


//
// Old FragmentGI signature. Kept only for backward compatibility and will be removed soon
//

inline UnityGI FragmentGI(
    float3 posWorld,
    half occlusion, half4 i_ambientOrLightmapUV, half atten, half smoothness, half3 normalWorld, half3 eyeVec,
    UnityLight light,
    bool reflections)
{
    // we init only fields actually used
    FragmentCommonData s = (FragmentCommonData)0;
    s.smoothness = smoothness;
    s.normalWorld = normalWorld;
    s.eyeVec = eyeVec;
    s.posWorld = posWorld;
    return FragmentGI(s, occlusion, i_ambientOrLightmapUV, atten, light, reflections);
}
inline UnityGI FragmentGI (
    float3 posWorld,
    half occlusion, half4 i_ambientOrLightmapUV, half atten, half smoothness, half3 normalWorld, half3 eyeVec,
    UnityLight light)
{
    return FragmentGI (posWorld, occlusion, i_ambientOrLightmapUV, atten, smoothness, normalWorld, eyeVec, light, true);
}

#endif // UNITY_STANDARD_CORE_INCLUDED
