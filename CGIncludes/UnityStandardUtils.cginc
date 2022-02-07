// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

#ifndef UNITY_STANDARD_UTILS_INCLUDED
#define UNITY_STANDARD_UTILS_INCLUDED

#include "UnityCG.cginc"
#include "UnityStandardConfig.cginc"

// Helper functions, maybe move into UnityCG.cginc

half SpecularStrength(half3 specular)   // 计算镜面高光强度
{
    #if (SHADER_TARGET < 30) // Shader Model 3以下：强度是r通道
        // SM2.0: instruction count limitation
        // SM2.0: simplified SpecularStrength
        return specular.r; // Red channel - because most metals are either monocrhome or with redish/yellowish tint
    #else
        return max (max (specular.r, specular.g), specular.b);  // Shader Model 3：强度是rgb中的最大值
    #endif
}

// Diffuse/Spec Energy conservation 镜面反射时，计算漫反射的保存度，通常Cdiffuse + Cspecular > 入射光强度
inline half3 EnergyConservationBetweenDiffuseAndSpecular (half3 albedo, half3 specColor, out half oneMinusReflectivity)
{
    oneMinusReflectivity = 1 - SpecularStrength(specColor); // 计算1-反射度(漫反射占比)
    #if !UNITY_CONSERVE_ENERGY // 如果不保存能量
        return albedo;  // 直接返回反照率颜色
    #elif UNITY_CONSERVE_ENERGY_MONOCHROME  // 如果只保存漫反射能量
        return albedo * oneMinusReflectivity;   // 直接计算漫反射占比
    #else   // 需要保存能量
        return albedo * (half3(1,1,1) - specColor); // 漫反射能量需要减去镜面反射能量
    #endif
}
// 根据金属度计算1 - 反射度
inline half OneMinusReflectivityFromMetallic(half metallic)
{
    // We'll need oneMinusReflectivity, so
    //   1-reflectivity = 1-lerp(dielectricSpec, 1, metallic) = lerp(1-dielectricSpec, 0, metallic)
    // store (1-dielectricSpec) in unity_ColorSpaceDielectricSpec.a, then
    //   1-reflectivity = lerp(alpha, 0, metallic) = alpha + metallic*(0 - alpha) =
    //                  = alpha - metallic * alpha
    half oneMinusDielectricSpec = unity_ColorSpaceDielectricSpec.a;
    return oneMinusDielectricSpec - metallic * oneMinusDielectricSpec;
}
// 通过金属度计算漫反射和镜面反射颜色
inline half3 DiffuseAndSpecularFromMetallic (half3 albedo, half metallic, out half3 specColor, out half oneMinusReflectivity)
{
    specColor = lerp (unity_ColorSpaceDielectricSpec.rgb, albedo, metallic); // 计算反射颜色，根据金属度对电介质颜色和反照贴图的插值
    oneMinusReflectivity = OneMinusReflectivityFromMetallic(metallic);  // 计算 1-反射强度（漫反射强度）
    return albedo * oneMinusReflectivity; // 返回温反射颜色
}
// 漫反射预乘alpha，交根据材质的金属性对alpha进行处理
inline half3 PreMultiplyAlpha (half3 diffColor, half alpha, half oneMinusReflectivity, out half outModifiedAlpha)
{
    #if defined(_ALPHAPREMULTIPLY_ON) // 如果开启了预乘
        // NOTE: shader relies on pre-multiply alpha-blend (_SrcBlend = One, _DstBlend = OneMinusSrcAlpha)

        // Transparency 'removes' from Diffuse component
        diffColor *= alpha; // 预乘

        #if (SHADER_TARGET < 30) // 小于Shader Model 3.0，什么也不干
            // SM2.0: instruction count limitation
            // Instead will sacrifice part of physically based transparency where amount Reflectivity is affecting Transparency
            // SM2.0: uses unmodified alpha
            outModifiedAlpha = alpha;
        #else // Shader Model 3.0
            // Reflectivity 'removes' from the rest of components, including Transparency
            // outAlpha = 1-(1-alpha)*(1-reflectivity) = 1-(oneMinusReflectivity - alpha*oneMinusReflectivity) =
            //          = 1-oneMinusReflectivity + alpha*oneMinusReflectivity
            outModifiedAlpha = 1-oneMinusReflectivity + alpha*oneMinusReflectivity; // 重新计算alpha ？？？
        #endif
    #else // 否则什么也不干
        outModifiedAlpha = alpha;
    #endif
    return diffColor;   // 返回处理后的漫反射颜色
}

// Same as ParallaxOffset in Unity CG, except:  // 和UnityCG.cginc里的一样
//  *) precision - half instead of float
half2 ParallaxOffset1Step (half h, half height, half3 viewDir)  //  计算视差纹理的uv偏移
{
    h = h * height - height/2.0;
    half3 v = normalize(viewDir);
    v.z += 0.42;
    return h * (v.xy / v.z);
}
// 给定插件系数t，对输入值和1之间的线性插值
half LerpOneTo(half b, half t)
{
    half oneMinusT = 1 - t;
    return oneMinusT + b * t;
}
// 给定插件系数t，对输入颜色跟白色进行线性插值
half3 LerpWhiteTo(half3 b, half t)
{
    half oneMinusT = 1 - t;
    return half3(oneMinusT, oneMinusT, oneMinusT) + b * t;
}
// 解码DXT5nm格式的法线贴图（含法线系数）
half3 UnpackScaleNormalDXT5nm(half4 packednormal, half bumpScale)
{
    half3 normal;
    normal.xy = (packednormal.wy * 2 - 1);  // 法线的xy分量进行解码
    #if (SHADER_TARGET >= 30)
        // SM2.0: instruction count limitation
        // SM2.0: normal scaler is not supported
        normal.xy *= bumpScale; // 大于Shader Model 3，xy分量乘以法线系数
    #endif
    normal.z = sqrt(1.0 - saturate(dot(normal.xy, normal.xy))); // 重新计算z分量
    return normal;
}
// 可以同时解码DXT5nm和BC5两种格式的法线贴图（含法线系数）
half3 UnpackScaleNormalRGorAG(half4 packednormal, half bumpScale)
{
    #if defined(UNITY_NO_DXT5nm)    // 法向量为xyz通道, BC5 (x, y, 0, 1)
        half3 normal = packednormal.xyz * 2 - 1;    // [0, 1] => [-1, 1]
        #if (SHADER_TARGET >= 30)
            // SM2.0: instruction count limitation
            // SM2.0: normal scaler is not supported
            normal.xy *= bumpScale; // 大于Shader Model 3，xy分量乘以法线系数
        #endif
        return normal;
    #else // 如果使用DXT5nm格式
        // This do the trick, DXT5nm (1, y, 1, x)
        packednormal.x *= packednormal.w;

        half3 normal;
        normal.xy = (packednormal.xy * 2 - 1);    // [0, 1] => [-1, 1]
        #if (SHADER_TARGET >= 30)
            // SM2.0: instruction count limitation
            // SM2.0: normal scaler is not supported
            normal.xy *= bumpScale; // 大于Shader Model 3，xy分量乘以法线系数
        #endif
        normal.z = sqrt(1.0 - saturate(dot(normal.xy, normal.xy))); // 重新计算z分量
        return normal;
    #endif
}
// 解码法线纹理（含法线系数）
half3 UnpackScaleNormal(half4 packednormal, half bumpScale)
{
    return UnpackScaleNormalRGorAG(packednormal, bumpScale);
}
// 混全法向量
half3 BlendNormals(half3 n1, half3 n2)
{
    return normalize(half3(n1.xy + n2.xy, n1.z*n2.z));  // 向量相加后归一化
}
// 构建切线空间基向量矩阵
half3x3 CreateTangentToWorldPerVertex(half3 normal, half3 tangent, half tangentSign)
{
    // For odd-negative scale transforms we need to flip the sign
    half sign = tangentSign * unity_WorldTransformParams.w; // 切线方向符号
    half3 binormal = cross(normal, tangent) * sign; // 副法线
    return half3x3(tangent, binormal, normal);
}

//-------------------------------------------------------------------------------------
half3 ShadeSHPerVertex (half3 normal, half3 ambient) // 逐顶点计算球谐环境光
{
    #if UNITY_SAMPLE_FULL_SH_PER_PIXEL  // 如果设置在逐片元计算，则直接返回环境光
        // Completely per-pixel
        // nothing to do here
    #elif (SHADER_TARGET < 30) || UNITY_STANDARD_SIMPLE // 如果小于Shader Model 3.0，或者简单标准着色
        // Completely per-vertex    // 逐顶点计算球谐环境光
        ambient += max(half3(0,0,0), ShadeSH9 (half4(normal, 1.0)));    // UnityCG.cginc, L361
    #else   // 如果Shader Model 3.0或者标准着色，L0,L1的部分在片元中计算，L2的部分在顶点计算
        // L2 per-vertex, L0..L1 & gamma-correction per-pixel

        // NOTE: SH data is always in Linear AND calculation is split between vertex & pixel
        // Convert ambient to Linear and do final gamma-correction at the end (per-pixel)
        #ifdef UNITY_COLORSPACE_GAMMA   // 如果是Gamma颜色空间，转换到线性空间
            ambient = GammaToLinearSpace (ambient);
        #endif
        ambient += SHEvalLinearL2 (half4(normal, 1.0));     // no max since this is only L2 contribution
    #endif

    return ambient;
}
// 逐片元计算球谐环境光
half3 ShadeSHPerPixel (half3 normal, half3 ambient, float3 worldPos)
{
    half3 ambient_contrib = 0.0;

    #if UNITY_SAMPLE_FULL_SH_PER_PIXEL  // 逐片元计算球谐
        // Completely per-pixel
        #if UNITY_LIGHT_PROBE_PROXY_VOLUME
            if (unity_ProbeVolumeParams.x == 1.0)   // 如果此LPPV生效，对LPPV进行采样后，再计算L0L1阶计算
                ambient_contrib = SHEvalLinearL0L1_SampleProbeVolume(half4(normal, 1.0), worldPos);
            else    // 如果此LPPV未生效，进行L0L1阶计算
                ambient_contrib = SHEvalLinearL0L1(half4(normal, 1.0));
        #else   // 如果没有启动LPPV，进行L0L1阶计算
            ambient_contrib = SHEvalLinearL0L1(half4(normal, 1.0));
        #endif

            ambient_contrib += SHEvalLinearL2(half4(normal, 1.0));  // 计算L2阶球谐采样

            ambient += max(half3(0, 0, 0), ambient_contrib);

        #ifdef UNITY_COLORSPACE_GAMMA   // 如果是Gamma颜色空间，转换到线性空间
            ambient = LinearToGammaSpace(ambient);
        #endif
    #elif (SHADER_TARGET < 30) || UNITY_STANDARD_SIMPLE  // 如果小于Shader Model 3.0，或者简单标准着色，已被顶点中处理
        // Completely per-vertex
        // nothing to do here. Gamma conversion on ambient from SH takes place in the vertex shader, see ShadeSHPerVertex.
    #else   // 如果Shader Model 3.0或者标准着色，需要计算L0,L1的部分，L2的部分已经在顶点计算
        // L2 per-vertex, L0..L1 & gamma-correction per-pixel
        // Ambient in this case is expected to be always Linear, see ShadeSHPerVertex()
        #if UNITY_LIGHT_PROBE_PROXY_VOLUME
            if (unity_ProbeVolumeParams.x == 1.0)   // 如果此LPPV生效，对LPPV进行采样后，再计算L0L1阶计算
                ambient_contrib = SHEvalLinearL0L1_SampleProbeVolume (half4(normal, 1.0), worldPos);
            else    // 如果此LPPV未生效，进行L0L1阶计算
                ambient_contrib = SHEvalLinearL0L1 (half4(normal, 1.0));
        #else   // 如果没有启动LPPV，进行L0L1阶计算
            ambient_contrib = SHEvalLinearL0L1 (half4(normal, 1.0));
        #endif

        ambient = max(half3(0, 0, 0), ambient+ambient_contrib);     // include L2 contribution in vertex shader before clamp.
        #ifdef UNITY_COLORSPACE_GAMMA   // 如果是Gamma颜色空间，转换到线性空间
            ambient = LinearToGammaSpace (ambient);
        #endif
    #endif

    return ambient;
}
//-------------------------------------------------------------------------------------
// Reflection Probe中开启了Box Projection，需要根据从当前位置观察到的点，转化为box中心射向观察到的点的方向
inline float3 BoxProjectedCubemapDirection (float3 worldRefl, float3 worldPos, float4 cubemapCenter, float4 boxMin, float4 boxMax)
{
    // Do we have a valid reflection probe?  // 如果观察位置就在中心点，或者像天空盒这样无限远，不需要重新计算反射方向
    UNITY_BRANCH
    if (cubemapCenter.w > 0.0)
    {
        float3 nrdir = normalize(worldRefl);    // 先归一化反射向量

        #if 1
            float3 rbmax = (boxMax.xyz - worldPos) / nrdir; // nrdir * rbmax = boxMax.xyz - worldPos，向量到达Xmax, Ymax, Zmax的模
            float3 rbmin = (boxMin.xyz - worldPos) / nrdir; // nrdir * rbmax = boxMax.xyz - worldPos，向量到达Xmin, Ymin, Zmin的模

            float3 rbminmax = (nrdir > 0.0f) ? rbmax : rbmin;   // 计算碰撞的面是哪三个轴

        #else // Optimized version
            float3 rbmax = (boxMax.xyz - worldPos);
            float3 rbmin = (boxMin.xyz - worldPos);

            float3 select = step (float3(0,0,0), nrdir);
            float3 rbminmax = lerp (rbmax, rbmin, select);
            rbminmax /= nrdir;
        #endif

        float fa = min(min(rbminmax.x, rbminmax.y), rbminmax.z);    // 从起点出发，发生碰撞的时候，最短的距离就是需要的长度

        worldPos -= cubemapCenter.xyz;          // 中心点到观察位置的向量
        worldRefl = worldPos + nrdir * fa;      // 中心点到观察位置的向量 + 观察向量 * 模 = 中心点到采样点的向量
    }
    return worldRefl;
}


//-------------------------------------------------------------------------------------
// Derivative maps
// http://www.rorydriscoll.com/2012/01/11/derivative-maps/
// For future use.

// Project the surface gradient (dhdx, dhdy) onto the surface (n, dpdx, dpdy)
half3 CalculateSurfaceGradient(half3 n, half3 dpdx, half3 dpdy, half dhdx, half dhdy)
{
    half3 r1 = cross(dpdy, n);
    half3 r2 = cross(n, dpdx);
    return (r1 * dhdx + r2 * dhdy) / dot(dpdx, r1);
}

// Move the normal away from the surface normal in the opposite surface gradient direction
half3 PerturbNormal(half3 n, half3 dpdx, half3 dpdy, half dhdx, half dhdy)
{
    //TODO: normalize seems to be necessary when scales do go beyond the 2...-2 range, should we limit that?
    //how expensive is a normalize? Anything cheaper for this case?
    return normalize(n - CalculateSurfaceGradient(n, dpdx, dpdy, dhdx, dhdy));
}

// Calculate the surface normal using the uv-space gradient (dhdu, dhdv)
half3 CalculateSurfaceNormal(half3 position, half3 normal, half2 gradient, half2 uv)
{
    half3 dpdx = ddx(position);
    half3 dpdy = ddy(position);

    half dhdx = dot(gradient, ddx(uv));
    half dhdy = dot(gradient, ddy(uv));

    return PerturbNormal(normal, dpdx, dpdy, dhdx, dhdy);
}


#endif // UNITY_STANDARD_UTILS_INCLUDED
