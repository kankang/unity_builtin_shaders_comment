// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

#ifndef UNITY_GBUFFER_INCLUDED
#define UNITY_GBUFFER_INCLUDED

//-----------------------------------------------------------------------------
// Main structure that store the data from the standard shader (i.e user input)
struct UnityStandardData    // 标准着色器数据
{
    half3   diffuseColor;   // 漫反射颜色
    half    occlusion;      // AO值

    half3   specularColor;  // 镜面反射颜色
    half    smoothness;     // 光滑度值

    float3  normalWorld;        // normal in world space, 世界空间法向量
};

//-----------------------------------------------------------------------------
// This will encode UnityStandardData into GBuffer，写入GBuffer
void UnityStandardDataToGbuffer(UnityStandardData data, out half4 outGBuffer0, out half4 outGBuffer1, out half4 outGBuffer2)
{
    // RT0: diffuse color (rgb), occlusion (a) - sRGB rendertarget
    outGBuffer0 = half4(data.diffuseColor, data.occlusion); // 漫反射颜色 => RT0.rgb，AO => RT0.a

    // RT1: spec color (rgb), smoothness (a) - sRGB rendertarget
    outGBuffer1 = half4(data.specularColor, data.smoothness);   // 镜面高光反射颜色 => RT1.rgb，光滑度 => RT1.a

    // RT2: normal (rgb), --unused, very low precision-- (a)
    outGBuffer2 = half4(data.normalWorld * 0.5f + 0.5f, 1.0f);  // 世界空间法向量 => [0, 1] => RT2.rgb,
}
//-----------------------------------------------------------------------------
// This decode the Gbuffer in a UnityStandardData struct, 读取GBuffer
UnityStandardData UnityStandardDataFromGbuffer(half4 inGBuffer0, half4 inGBuffer1, half4 inGBuffer2)
{
    UnityStandardData data; // 声明标准数据结构体

    data.diffuseColor   = inGBuffer0.rgb;   // RT0.rgb => 漫反射颜色
    data.occlusion      = inGBuffer0.a;     // RT0.a => AO值

    data.specularColor  = inGBuffer1.rgb;   // RT1.rgb => 镜面反射颜色
    data.smoothness     = inGBuffer1.a;     // RT1.a => 光滑度

    data.normalWorld    = normalize((float3)inGBuffer2.rgb * 2 - 1);    // RT2.rgb => [-1, 1] => 法向量

    return data;
}
//-----------------------------------------------------------------------------
// In some cases like for terrain, the user want to apply a specific weight to the attribute
// The function below is use for this， 有时候需要对gbuffer里的值进行调整
void UnityStandardDataApplyWeightToGbuffer(inout half4 inOutGBuffer0, inout half4 inOutGBuffer1, inout half4 inOutGBuffer2, half alpha)
{
    // With UnityStandardData current encoding, We can apply the weigth directly on the gbuffer
    inOutGBuffer0.rgb   *= alpha; // diffuseColor
    inOutGBuffer1       *= alpha; // SpecularColor and Smoothness
    inOutGBuffer2.rgb   *= alpha; // Normal
}
//-----------------------------------------------------------------------------

#endif // #ifndef UNITY_GBUFFER_INCLUDED
