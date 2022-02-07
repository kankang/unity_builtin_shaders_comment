// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

#ifndef UNITY_GLOBAL_ILLUMINATION_INCLUDED
#define UNITY_GLOBAL_ILLUMINATION_INCLUDED

// Functions sampling light environment data (lightmaps, light probes, reflection probes), which is then returned as the UnityGI struct.

#include "UnityImageBasedLighting.cginc"
#include "UnityStandardUtils.cginc"
#include "UnityShadowLibrary.cginc"

inline half3 DecodeDirectionalSpecularLightmap (half3 color, half4 dirTex, half3 normalWorld, bool isRealtimeLightmap, fixed4 realtimeNormalTex, out UnityLight o_light)
{
    o_light.color = color;
    o_light.dir = dirTex.xyz * 2 - 1;
    o_light.ndotl = 0; // Not use;

    // The length of the direction vector is the light's "directionality", i.e. 1 for all light coming from this direction,
    // lower values for more spread out, ambient light.
    half directionality = max(0.001, length(o_light.dir));
    o_light.dir /= directionality;

    #ifdef DYNAMICLIGHTMAP_ON
    if (isRealtimeLightmap)
    {
        // Realtime directional lightmaps' intensity needs to be divided by N.L
        // to get the incoming light intensity. Baked directional lightmaps are already
        // output like that (including the max() to prevent div by zero).
        half3 realtimeNormal = realtimeNormalTex.xyz * 2 - 1;
        o_light.color /= max(0.125, dot(realtimeNormal, o_light.dir));
    }
    #endif

    // Split light into the directional and ambient parts, according to the directionality factor.
    half3 ambient = o_light.color * (1 - directionality);
    o_light.color = o_light.color * directionality;

    // Technically this is incorrect, but helps hide jagged light edge at the object silhouettes and
    // makes normalmaps show up.
    ambient *= saturate(dot(normalWorld, o_light.dir));
    return ambient;
}
// 对UnityLight清0
inline void ResetUnityLight(out UnityLight outLight)
{
    outLight.color = half3(0, 0, 0);
    outLight.dir = half3(0, 1, 0); // Irrelevant direction, just not null
    outLight.ndotl = 0; // Not used
}
// 把基于全局照明预先生成的光照贴图减去实时光源在运行期得到的颜色值
inline half3 SubtractMainLightWithRealtimeAttenuationFromLightmap (half3 lightmap, half attenuation, half4 bakedColorTex, half3 normalWorld)
{
    // Let's try to make realtime shadows work on a surface, which already contains
    // baked lighting and shadowing from the main sun light.
    half3 shadowColor = unity_ShadowColor.rgb;  // 阴影颜色
    half shadowStrength = _LightShadowData.x;   // 阴影强度

    // Summary:
    // 1) Calculate possible value in the shadow by subtracting estimated light contribution from the places occluded by realtime shadow:
    //      a) preserves other baked lights and light bounces
    //      b) eliminates shadows on the geometry facing away from the light
    // 2) Clamp against user defined ShadowColor.
    // 3) Pick original lightmap value, if it is the darkest one.


    // 1) Gives good estimate of illumination as if light would've been shadowed during the bake.
    //    Preserves bounce and other baked lights
    //    No shadows on the geometry facing away from the light
    half ndotl = LambertTerm (normalWorld, _WorldSpaceLightPos0.xyz);   // 计算两个向量的余弦
    half3 estimatedLightContributionMaskedByInverseOfShadow = ndotl * (1- attenuation) * _LightColor0.rgb;  // 实时光对本片元的光照贡献
    half3 subtractedLightmap = lightmap - estimatedLightContributionMaskedByInverseOfShadow;    // 光照贴图颜色减去实时光照的部分

    // 2) Allows user to define overall ambient of the scene and control situation when realtime shadow becomes too dark.
    half3 realtimeShadow = max(subtractedLightmap, shadowColor);    // 光照贴图减去实时光照颜色，与用户定义的阴影相比，取最大者做为实时阴影
    realtimeShadow = lerp(realtimeShadow, lightmap, shadowStrength);    // 根据阴影强度进行插值

    // 3) Pick darkest color，从lightmap和实际阴影中，使用最暗的颜色
    return min(lightmap, realtimeShadow);
}
// 对UnityGI清0
inline void ResetUnityGI(out UnityGI outGI)
{
    ResetUnityLight(outGI.light);
    outGI.indirect.diffuse = 0;
    outGI.indirect.specular = 0;
}
// 计算全局光照
inline UnityGI UnityGI_Base(UnityGIInput data, half occlusion, half3 normalWorld)
{
    UnityGI o_gi;
    ResetUnityGI(o_gi);

    // Base pass with Lightmap support is responsible for handling ShadowMask / blending here for performance reason
    #if defined(HANDLE_SHADOWS_BLENDING_IN_GI)
        half bakedAtten = UnitySampleBakedOcclusion(data.lightmapUV.xy, data.worldPos); // 采样烘焙的阴影衰减值
        float zDist = dot(_WorldSpaceCameraPos - data.worldPos, UNITY_MATRIX_V[2].xyz); // 深度值
        float fadeDist = UnityComputeShadowFadeDistance(data.worldPos, zDist);  // 根据当前片元到当前摄像机的距离值，计算阴影的淡化程度
        data.atten = UnityMixRealtimeAndBakedShadows(data.atten, bakedAtten, UnityComputeShadowFade(fadeDist)); // 同时对前向和延迟渲染路径进行渲染（对实时阴影和烘焙阴影进行混合处理，取最小）
    #endif

    o_gi.light = data.light;
    o_gi.light.color *= data.atten;

    #if UNITY_SHOULD_SAMPLE_SH
        o_gi.indirect.diffuse = ShadeSHPerPixel(normalWorld, data.ambient, data.worldPos);  // 环境光照
    #endif

    #if defined(LIGHTMAP_ON)  // 如果开启了光照贴图，间接光照的漫反射需要叠加动态光照贴图的采样
        // Baked lightmaps
        half4 bakedColorTex = UNITY_SAMPLE_TEX2D(unity_Lightmap, data.lightmapUV.xy);
        half3 bakedColor = DecodeLightmap(bakedColorTex);    // 烘焙光照贴图的颜色

        #ifdef DIRLIGHTMAP_COMBINED// 如果开启了方向光照贴图合并，则从贴图中获取定向光的入射辐射度方向
            fixed4 bakedDirTex = UNITY_SAMPLE_TEX2D_SAMPLER (unity_LightmapInd, unity_Lightmap, data.lightmapUV.xy);
            o_gi.indirect.diffuse += DecodeDirectionalLightmap (bakedColor, bakedDirTex, normalWorld);  // 从定向光照贴图中获取间接照明部分的漫反射颜色
            // 如果启用了阴影混合、基于屏幕空间的阴影、且未使用阴影蒙版，漫反射颜色通过SubtractMainLightWithRealtimeAttenuationFromLightmap来获取
            #if defined(LIGHTMAP_SHADOW_MIXING) && !defined(SHADOWS_SHADOWMASK) && defined(SHADOWS_SCREEN)
                ResetUnityLight(o_gi.light);
                o_gi.indirect.diffuse = SubtractMainLightWithRealtimeAttenuationFromLightmap (o_gi.indirect.diffuse, data.atten, bakedColorTex, normalWorld);
            #endif

        #else // not directional lightmap， 没有开启方向光照贴图合并
            o_gi.indirect.diffuse += bakedColor;    // 漫反射颜色使用烘焙当时贴图的颜色

            #if defined(LIGHTMAP_SHADOW_MIXING) && !defined(SHADOWS_SHADOWMASK) && defined(SHADOWS_SCREEN)
                ResetUnityLight(o_gi.light); // 如果启用了阴影混合、基于屏幕空间的阴影、且未使用阴影蒙版，漫反射颜色通过SubtractMainLightWithRealtimeAttenuationFromLightmap来获取
                o_gi.indirect.diffuse = SubtractMainLightWithRealtimeAttenuationFromLightmap(o_gi.indirect.diffuse, data.atten, bakedColorTex, normalWorld);
            #endif

        #endif
    #endif

    #ifdef DYNAMICLIGHTMAP_ON   // 如果开启了动态光照贴图，间接光照的漫反射需要叠加动态光照贴图的采样
        // Dynamic lightmaps
        fixed4 realtimeColorTex = UNITY_SAMPLE_TEX2D(unity_DynamicLightmap, data.lightmapUV.zw);
        half3 realtimeColor = DecodeRealtimeLightmap (realtimeColorTex);    // 动态光照贴图的颜色

        #ifdef DIRLIGHTMAP_COMBINED // 如果开启了方向光照贴图合并，则从贴图中获取定向光的入射辐射度方向
            half4 realtimeDirTex = UNITY_SAMPLE_TEX2D_SAMPLER(unity_DynamicDirectionality, unity_DynamicLightmap, data.lightmapUV.zw);
            o_gi.indirect.diffuse += DecodeDirectionalLightmap (realtimeColor, realtimeDirTex, normalWorld);  // 从定向光照贴图中获取间接照明部分的漫反射颜色
        #else
            o_gi.indirect.diffuse += realtimeColor;
        #endif
    #endif

    o_gi.indirect.diffuse *= occlusion; // 间接光照的漫反射需要乘以屏蔽衰减因子
    return o_gi;
}

// 计算间接光照的镜面反射颜色
inline half3 UnityGI_IndirectSpecular(UnityGIInput data, half occlusion, Unity_GlossyEnvironmentData glossIn)
{
    half3 specular;

    #ifdef UNITY_SPECCUBE_BOX_PROJECTION // Reflection Probe中开启了Box Projection，需要根据从当前位置观察到的点，转化为box中心射向观察到的点的方向
        // we will tweak reflUVW in glossIn directly (as we pass it to Unity_GlossyEnvironment twice for probe0 and probe1), so keep original to pass into BoxProjectedCubemapDirection
        half3 originalReflUVW = glossIn.reflUVW;
        glossIn.reflUVW = BoxProjectedCubemapDirection (originalReflUVW, data.worldPos, data.probePosition[0], data.boxMin[0], data.boxMax[0]); // UnityStancardUtils.cginc, L227
    #endif

    #ifdef _GLOSSYREFLECTIONS_OFF   // 如果光泽度返回未开启
        specular = unity_IndirectSpecColor.rgb; // 直接使用间接高光反射颜色
    #else
        half3 env0 = Unity_GlossyEnvironment (UNITY_PASS_TEXCUBE(unity_SpecCube0), data.probeHDR[0], glossIn);  // 获取环境贴图中的颜色作为材质表面反射场景所显示的内容
        #ifdef UNITY_SPECCUBE_BLENDING  // 启用反射用光探针的混合，TierSettings.reflectionProbeBlending = true;
            const float kBlendFactor = 0.99999;
            float blendLerp = data.boxMin[0].w;
            UNITY_BRANCH
            if (blendLerp < kBlendFactor)
            {
                #ifdef UNITY_SPECCUBE_BOX_PROJECTION // Reflection Probe中开启了Box Projection，需要根据从当前位置观察到的点，转化为box中心射向观察到的点的方向
                    glossIn.reflUVW = BoxProjectedCubemapDirection (originalReflUVW, data.worldPos, data.probePosition[1], data.boxMin[1], data.boxMax[1]);
                #endif

                half3 env1 = Unity_GlossyEnvironment (UNITY_PASS_TEXCUBE_SAMPLER(unity_SpecCube1,unity_SpecCube0), data.probeHDR[1], glossIn); // UnityStancardUtils.cginc, L227
                specular = lerp(env1, env0, blendLerp); // 对第1层、第2层环境光进行插值
            }
            else
            {
                specular = env0;
            }
        #else
            specular = env0;
        #endif
    #endif

    return specular * occlusion;    // 反射颜色 * 遮挡值
}

// Deprecated old prototype but can't be move to Deprecated.cginc file due to order dependency
inline half3 UnityGI_IndirectSpecular(UnityGIInput data, half occlusion, half3 normalWorld, Unity_GlossyEnvironmentData glossIn)
{
    // normalWorld is not used
    return UnityGI_IndirectSpecular(data, occlusion, glossIn);
}
// 计算的全局光照
inline UnityGI UnityGlobalIllumination (UnityGIInput data, half occlusion, half3 normalWorld)
{
    return UnityGI_Base(data, occlusion, normalWorld);
}
// 计算的全局光照
inline UnityGI UnityGlobalIllumination (UnityGIInput data, half occlusion, half3 normalWorld, Unity_GlossyEnvironmentData glossIn)
{
    UnityGI o_gi = UnityGI_Base(data, occlusion, normalWorld);
    o_gi.indirect.specular = UnityGI_IndirectSpecular(data, occlusion, glossIn);    // 间接光照的镜面高光反射
    return o_gi;
}

//
// Old UnityGlobalIllumination signatures. Kept only for backward compatibility and will be removed soon
//

inline UnityGI UnityGlobalIllumination (UnityGIInput data, half occlusion, half smoothness, half3 normalWorld, bool reflections)
{
    if(reflections)
    {
        Unity_GlossyEnvironmentData g = UnityGlossyEnvironmentSetup(smoothness, data.worldViewDir, normalWorld, float3(0, 0, 0));
        return UnityGlobalIllumination(data, occlusion, normalWorld, g);
    }
    else
    {
        return UnityGlobalIllumination(data, occlusion, normalWorld);
    }
}
inline UnityGI UnityGlobalIllumination (UnityGIInput data, half occlusion, half smoothness, half3 normalWorld)
{
#if defined(UNITY_PASS_DEFERRED) && UNITY_ENABLE_REFLECTION_BUFFERS
    // No need to sample reflection probes during deferred G-buffer pass
    bool sampleReflections = false;
#else
    bool sampleReflections = true;
#endif
    return UnityGlobalIllumination (data, occlusion, smoothness, normalWorld, sampleReflections);
}


#endif
