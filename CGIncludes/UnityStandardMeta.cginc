// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

#ifndef UNITY_STANDARD_META_INCLUDED
#define UNITY_STANDARD_META_INCLUDED

// Functionality for Standard shader "meta" pass
// (extracts albedo/emission for lightmapper etc.)

#include "UnityCG.cginc"
#include "UnityStandardInput.cginc"
#include "UnityMetaPass.cginc"
#include "UnityStandardCore.cginc"
// 元渲染顶点着色器输出数据
struct v2f_meta
{
    float4 pos      : SV_POSITION;  // 裁剪空间位置
    float4 uv       : TEXCOORD0;    // 第一层纹理坐标
#ifdef EDITOR_VISUALIZATION
    float2 vizUV        : TEXCOORD1;
    float4 lightCoord   : TEXCOORD2;
#endif
};
// 元渲染路径顶点着色器函数
v2f_meta vert_meta (VertexInput v)
{
    v2f_meta o; // 根据传入的顶点光照贴图纹理坐标，计算顶点在裁剪空间的位置
    o.pos = UnityMetaVertexPosition(v.vertex, v.uv1.xy, v.uv2.xy, unity_LightmapST, unity_DynamicLightmapST);   // UnityMetaPass.cginc, L261
    o.uv = TexCoords(v);    // 第一层纹理坐标
#ifdef EDITOR_VISUALIZATION
    o.vizUV = 0;
    o.lightCoord = 0;
    if (unity_VisualizationMode == EDITORVIZ_TEXTURE)
        o.vizUV = UnityMetaVizUV(unity_EditorViz_UVIndex, v.uv0.xy, v.uv1.xy, v.uv2.xy, unity_EditorViz_Texture_ST);
    else if (unity_VisualizationMode == EDITORVIZ_SHOWLIGHTMASK)
    {
        o.vizUV = v.uv1.xy * unity_LightmapST.xy + unity_LightmapST.zw;
        o.lightCoord = mul(unity_EditorViz_WorldToLight, mul(unity_ObjectToWorld, float4(v.vertex.xyz, 1)));
    }
#endif
    return o;
}

// Albedo for lightmapping should basically be diffuse color. 
// But rough metals (black diffuse) still scatter quite a lot of light around, so
// we want to take some of that into account too.
half3 UnityLightmappingAlbedo (half3 diffuse, half3 specular, half smoothness)  // 计算光照贴图的反照率颜色
{
    half roughness = SmoothnessToRoughness(smoothness); // 平滑度转粗糙度
    half3 res = diffuse;
    res += specular * roughness * 0.5;  // 漫反射 + 镜面反射颜色 * 粗糙度 * 0.5
    return res;
}
// 元渲染路径片元着色器函数
float4 frag_meta (v2f_meta i) : SV_Target
{
    // we're interested in diffuse & specular colors,
    // and surface roughness to produce final albedo.
    FragmentCommonData data = UNITY_SETUP_BRDF_INPUT (i.uv);    // 根据工作流声明并初始化通用片元数据

    UnityMetaInput o;   // 声明元渲染输入数据
    UNITY_INITIALIZE_OUTPUT(UnityMetaInput, o); // 数据归0

#ifdef EDITOR_VISUALIZATION
    o.Albedo = data.diffColor;
    o.VizUV = i.vizUV;
    o.LightCoord = i.lightCoord;
#else
    o.Albedo = UnityLightmappingAlbedo (data.diffColor, data.specColor, data.smoothness);  // 计算光照贴图的反照率颜色
#endif
    o.SpecularColor = data.specColor;   // 镜面高光反射颜色
    o.Emission = Emission(i.uv.xy);     // 自发光颜色

    return UnityMetaFragment(o);    // 计算颜色并输出，UnityMetaPass.cginc, L288
}

#endif // UNITY_STANDARD_META_INCLUDED
