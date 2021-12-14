// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

#ifndef UNITY_CG_INCLUDED
#define UNITY_CG_INCLUDED

#define UNITY_PI            3.14159265359f      // PI
#define UNITY_TWO_PI        6.28318530718f      // 2 * PI
#define UNITY_FOUR_PI       12.56637061436f     // 4 * PI
#define UNITY_INV_PI        0.31830988618f      // 1 / PI
#define UNITY_INV_TWO_PI    0.15915494309f      // 1 / (2*PI)
#define UNITY_INV_FOUR_PI   0.07957747155f      // 1 / (4*PI)
#define UNITY_HALF_PI       1.57079632679f      // PI / 2
#define UNITY_INV_HALF_PI   0.636619772367f     // 1 / (PI/2)

#define UNITY_HALF_MIN      6.103515625e-5  // 2^-14, the same value for 10, 11 and 16-bit: https://www.khronos.org/opengl/wiki/Small_Float_Formats

// Should SH (light probe / ambient) calculations be performed?
// - When both static and dynamic lightmaps are available, no SH evaluation is performed
// - When static and dynamic lightmaps are not available, SH evaluation is always performed
// - For low level LODs, static lightmap and real-time GI from light probes can be combined together
// - Passes that don't do ambient (additive, shadowcaster etc.) should not do SH either.
#define UNITY_SHOULD_SAMPLE_SH (defined(LIGHTPROBE_SH) && !defined(UNITY_PASS_FORWARDADD) && !defined(UNITY_PASS_PREPASSBASE) && !defined(UNITY_PASS_SHADOWCASTER) && !defined(UNITY_PASS_META))

#include "UnityShaderVariables.cginc"
#include "UnityShaderUtilities.cginc"
#include "UnityInstancing.cginc"
// 定义Gamma颜色空间和Linear颜色空间的一些颜色数值
#ifdef UNITY_COLORSPACE_GAMMA
#define unity_ColorSpaceGrey fixed4(0.5, 0.5, 0.5, 0.5)
#define unity_ColorSpaceDouble fixed4(2.0, 2.0, 2.0, 2.0)
#define unity_ColorSpaceDielectricSpec half4(0.220916301, 0.220916301, 0.220916301, 1.0 - 0.220916301)
#define unity_ColorSpaceLuminance half4(0.22, 0.707, 0.071, 0.0) // Legacy: alpha is set to 0.0 to specify gamma mode
#else // Linear values
#define unity_ColorSpaceGrey fixed4(0.214041144, 0.214041144, 0.214041144, 0.5)
#define unity_ColorSpaceDouble fixed4(4.59479380, 4.59479380, 4.59479380, 2.0)
#define unity_ColorSpaceDielectricSpec half4(0.04, 0.04, 0.04, 1.0 - 0.04) // standard dielectric reflectivity coef at incident angle (= 4%)
#define unity_ColorSpaceLuminance half4(0.0396819152, 0.458021790, 0.00609653955, 1.0) // Legacy: alpha is set to 1.0 to specify linear mode
#endif

// -------------------------------------------------------------------
//  helper functions and macros used in many standard shaders


#if defined (DIRECTIONAL) || defined (DIRECTIONAL_COOKIE) || defined (POINT) || defined (SPOT) || defined (POINT_NOATT) || defined (POINT_COOKIE)
#define USING_LIGHT_MULTI_COMPILE   // 启用了光照（方向光、点光、聚光等）
#endif

#if defined(SHADER_API_D3D11) || defined(SHADER_API_PSSL) || defined(SHADER_API_METAL) || defined(SHADER_API_GLCORE) || defined(SHADER_API_GLES3) || defined(SHADER_API_VULKAN) || defined(SHADER_API_SWITCH) // D3D11, D3D12, XB1, PS4, iOS, macOS, tvOS, glcore, gles3, webgl2.0, Switch
// Real-support for depth-format cube shadow map.
#define SHADOWS_CUBE_IN_DEPTH_TEX
#endif

#define SCALED_NORMAL v.normal


// These constants must be kept in sync with RGBMRanges.h
#define LIGHTMAP_RGBM_SCALE 5.0
#define EMISSIVE_RGBM_SCALE 97.0
// 从CPU传给GPU基本的数据信息
struct appdata_base {
    float4 vertex : POSITION;       // 世界坐标下的顶点坐标
    float3 normal : NORMAL;         // 顶点法线
    float4 texcoord : TEXCOORD0;    // 顶点使用的第一层纹理坐标
    UNITY_VERTEX_INPUT_INSTANCE_ID  // 顶点多例化ID
};
// 从CPU传给GPU带切线数据的信息
struct appdata_tan {
    float4 vertex : POSITION;       // 世界坐标下的顶点坐标
    float4 tangent : TANGENT;       // 顶点切线
    float3 normal : NORMAL;         // 顶点法线
    float4 texcoord : TEXCOORD0;    // 顶点使用的第一层纹理坐标
    UNITY_VERTEX_INPUT_INSTANCE_ID  // 顶点多例化ID
};
// 从CPU传给GPU的全部数据信息
struct appdata_full {
    float4 vertex : POSITION;       // 世界坐标下的顶点坐标
    float4 tangent : TANGENT;
    float3 normal : NORMAL;         // 顶点法线
    float4 texcoord : TEXCOORD0;    // 顶点使用的第一层纹理坐标
    float4 texcoord1 : TEXCOORD1;   // 顶点使用的第二层纹理坐标
    float4 texcoord2 : TEXCOORD2;   // 顶点使用的第三层纹理坐标
    float4 texcoord3 : TEXCOORD3;   // 顶点使用的第四层纹理坐标
    fixed4 color : COLOR;           // 顶点颜色
    UNITY_VERTEX_INPUT_INSTANCE_ID  // 顶点多例化ID
};

// Legacy for compatibility with existing shaders
inline bool IsGammaSpace()      // 是否启动了Gamma颜色空间
{
    #ifdef UNITY_COLORSPACE_GAMMA
        return true;
    #else
        return false;
    #endif
}
// 把颜色从Gamma颜色空间精确地变换到线性颜色空间
inline float GammaToLinearSpaceExact (float value)
{
    if (value <= 0.04045F)
        return value / 12.92F;
    else if (value < 1.0F)
        return pow((value + 0.055F)/1.055F, 2.4F);
    else
        return pow(value, 2.2F);
}
// 使用近似模拟的函数把sGRB颜色从Gamma颜色空间变换到线性颜色空间（CIE-XYZ）
inline half3 GammaToLinearSpace (half3 sRGB)
{
    // Approximate version from http://chilliant.blogspot.com.au/2012/08/srgb-approximations-for-hlsl.html?m=1
    return sRGB * (sRGB * (sRGB * 0.305306011h + 0.682171111h) + 0.012522878h);

    // Precise version, useful for debugging.
    //return half3(GammaToLinearSpaceExact(sRGB.r), GammaToLinearSpaceExact(sRGB.g), GammaToLinearSpaceExact(sRGB.b));
}
// 把颜色从线性颜色空间精确地变换到Gamma颜色空间
inline float LinearToGammaSpaceExact (float value)
{
    if (value <= 0.0F)
        return 0.0F;
    else if (value <= 0.0031308F)
        return 12.92F * value;
    else if (value < 1.0F)
        return 1.055F * pow(value, 0.4166667F) - 0.055F;
    else
        return pow(value, 0.45454545F);
}
// 使用近似模拟的函数把颜色从线性颜色空间变换到Gamma颜色空间
inline half3 LinearToGammaSpace (half3 linRGB)
{
    linRGB = max(linRGB, half3(0.h, 0.h, 0.h));
    // An almost-perfect approximation from http://chilliant.blogspot.com.au/2012/08/srgb-approximations-for-hlsl.html?m=1
    return max(1.055h * pow(linRGB, 0.416666667h) - 0.055h, 0.h);

    // Exact version, useful for debugging.
    //return half3(LinearToGammaSpaceExact(linRGB.r), LinearToGammaSpaceExact(linRGB.g), LinearToGammaSpaceExact(linRGB.b));
}

// Tranforms position from world to homogenous space 世界空间的点转换至裁剪空间
inline float4 UnityWorldToClipPos( in float3 pos )
{
    return mul(UNITY_MATRIX_VP, float4(pos, 1.0));
}

// Tranforms position from view to homogenous space 观察空间的点转换至裁剪空间
inline float4 UnityViewToClipPos( in float3 pos )
{
    return mul(UNITY_MATRIX_P, float4(pos, 1.0));
}

// Tranforms position from object to camera space 模型空间的点转换至观察空间
inline float3 UnityObjectToViewPos( in float3 pos )
{
    return mul(UNITY_MATRIX_V, mul(unity_ObjectToWorld, float4(pos, 1.0))).xyz;
}
inline float3 UnityObjectToViewPos(float4 pos) // overload for float4; avoids "implicit truncation" warning for existing shaders
{
    return UnityObjectToViewPos(pos.xyz);
}

// Tranforms position from world to camera space 世界空间的点转换至观察空间
inline float3 UnityWorldToViewPos( in float3 pos )
{
    return mul(UNITY_MATRIX_V, float4(pos, 1.0)).xyz;
}

// Transforms direction from object to world space 模型空间的方向转换至世界空间
inline float3 UnityObjectToWorldDir( in float3 dir )
{
    return normalize(mul((float3x3)unity_ObjectToWorld, dir));
}

// Transforms direction from world to object space 世界空间的方向转换至模型空间
inline float3 UnityWorldToObjectDir( in float3 dir )
{
    return normalize(mul((float3x3)unity_WorldToObject, dir));
}

// Transforms normal from object to world space 模型空间的法线转换至世界空间
inline float3 UnityObjectToWorldNormal( in float3 norm )
{
#ifdef UNITY_ASSUME_UNIFORM_SCALING  // 等比缩放，即x,y,z缩放相同，那么可以直接转换至世界空间
    return UnityObjectToWorldDir(norm);
#else  // 非等比缩放，为了保持法线方向的正确性，需要做如下矩阵变换：
    // mul(IT_M, norm) => mul(norm, I_M) => {dot(norm, I_M.col0), dot(norm, I_M.col1), dot(norm, I_M.col2)}
    return normalize(mul(norm, (float3x3)unity_WorldToObject)); // 参考：https://www.freesion.com/article/8712512300/
#endif
}

// Computes world space light direction, from world space position 世界坐标系下，通过灯光位置计算灯光方向
inline float3 UnityWorldSpaceLightDir( in float3 worldPos )
{
    #ifndef USING_LIGHT_MULTI_COMPILE  // 未启用光照
        return _WorldSpaceLightPos0.xyz - worldPos * _WorldSpaceLightPos0.w;
    #else // 启用了光照
        #ifndef USING_DIRECTIONAL_LIGHT
        return _WorldSpaceLightPos0.xyz - worldPos;     // 非方向光计算光位置指向顶点世界坐标的方向
        #else 
        return _WorldSpaceLightPos0.xyz;  // 方向光直接返回世界空间中光的位置
        #endif
    #endif
}

// Computes world space light direction, from object space position 从模型空间上的位置计算世界空间光的方向
// *Legacy* Please use UnityWorldSpaceLightDir instead 已废弃，使用UnityWorldSpaceLightDir
inline float3 WorldSpaceLightDir( in float4 localPos )
{
    float3 worldPos = mul(unity_ObjectToWorld, localPos).xyz;
    return UnityWorldSpaceLightDir(worldPos);
}

// Computes object space light direction 计算模型空间光的方向
inline float3 ObjSpaceLightDir( in float4 v )
{
    float3 objSpaceLightPos = mul(unity_WorldToObject, _WorldSpaceLightPos0).xyz;   // 计算模型空间中灯的位置
    #ifndef USING_LIGHT_MULTI_COMPILE   // 未启用光照
        return objSpaceLightPos.xyz - v.xyz * _WorldSpaceLightPos0.w;
    #else  // 启用了光照
        #ifndef USING_DIRECTIONAL_LIGHT
        return objSpaceLightPos.xyz - v.xyz; // 非方向光计算光位置指向顶点位置的方向
        #else
        return objSpaceLightPos.xyz;   // 方向光返回模型空间中光的位置
        #endif
    #endif
}

// Computes world space view direction, from object (world???) space position 世界空间中某位置与观察位置（摄像机）的连线向量
inline float3 UnityWorldSpaceViewDir( in float3 worldPos )
{
    return _WorldSpaceCameraPos.xyz - worldPos;
}

// Computes world space view direction, from object space position 模型空间中某位置与观察位置（摄像机）的连线向量
// *Legacy* Please use UnityWorldSpaceViewDir instead
inline float3 WorldSpaceViewDir( in float4 localPos )
{
    float3 worldPos = mul(unity_ObjectToWorld, localPos).xyz;
    return UnityWorldSpaceViewDir(worldPos);
}

// Computes object space view direction 模型空间中观察位置（摄像机）与某个位置的连线向量
inline float3 ObjSpaceViewDir( in float4 v )
{
    float3 objSpaceCameraPos = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos.xyz, 1)).xyz;
    return objSpaceCameraPos - v.xyz;
}

// Declares 3x3 matrix 'rotation', filled with tangent space basis 定义切线空间的标准正交基，由顶点的切线、法线和副法线组成
#define TANGENT_SPACE_ROTATION \
    float3 binormal = cross( normalize(v.normal), normalize(v.tangent.xyz) ) * v.tangent.w; \
    float3x3 rotation = float3x3( v.tangent.xyz, binormal, v.normal )



// Used in ForwardBase pass: Calculates diffuse lighting from 4 point lights, with data packed in a special way. 前向渲染通道
float3 Shade4PointLights (  // 计算顶点被4个点光源照亮时的漫反射效果（Lambert lighting model）
    float4 lightPosX, float4 lightPosY, float4 lightPosZ,   // 传入4个点光源的x,y,z坐标
    float3 lightColor0, float3 lightColor1, float3 lightColor2, float3 lightColor3, // 传入4个点光源的RGB值
    float4 lightAttenSq,    // 传入4个点光源的二次项衰减系数
    float3 pos, float3 normal)  // 顶点位置、法线
{
    // to light vectors 计算顶点到每一个光源的距离x,y,z
    float4 toLightX = lightPosX - pos.x;        // | x0, x1, x2, x3 |
    float4 toLightY = lightPosY - pos.y;        // | y0, y1, y2, y3 |
    float4 toLightZ = lightPosZ - pos.z;        // | z0, z1, z2, z3 |
    // squared lengths 计算顶点到每一个光源的距离的平方和   (x1, y1) * (x2, y2) = (x1 * x2, y1 * y2)
    float4 lengthSq = 0;                        //                                                  | x0^2 + y0^2 + z0^2 |
    lengthSq += toLightX * toLightX;            // | x0 * x0, x1 * x1, x2 * x2, x3 * x3 |           | x1^2 + y1^2 + z1^2 |
    lengthSq += toLightY * toLightY;            // | y0 * y0, y1 * y1, y2 * y2, y3 * y3 |    ==>>   | x2^2 + y2^2 + z2^2 |
    lengthSq += toLightZ * toLightZ;            // | z0 * z0, z1 * z1, z2 * z2, z3 * z3 |           | x3^2 + y3^2 + z3^2 |
    // don't produce NaNs if some vertex position overlaps with the light 防止光源过近，距离为0
    lengthSq = max(lengthSq, 0.000001);

    // NdotL 计算顶点到4个点光源的向量与顶点法线的点乘
    float4 ndotl = 0;
    ndotl += toLightX * normal.x;        // | x0 * nx, x1 * nx, x2 * nx, x3 * nx |
    ndotl += toLightY * normal.y;        // | y0 * ny, y1 * ny, y2 * ny, y3 * ny |
    ndotl += toLightZ * normal.z;        // | z0 * nz, z1 * nz, z2 * nz, z3 * nz |
    // correct NdotL 归一化
    float4 corr = rsqrt(lengthSq);      // 平方根的倒数，牛顿-拉夫森（Newton-Rapson)迭代法，效率比求平方根要高
    ndotl = max (float4(0,0,0,0), ndotl * corr);    // Lambert Lighting
    // attenuation 衰减
    float4 atten = 1.0 / (1.0 + lengthSq * lightAttenSq);
    float4 diff = ndotl * atten;    // 强度
    // final color 最终颜色为四盏灯的颜色*强度之和
    float3 col = 0;
    col += lightColor0 * diff.x;
    col += lightColor1 * diff.y;
    col += lightColor2 * diff.z;
    col += lightColor3 * diff.w;
    return col;
}

// Used in Vertex pass: Calculates diffuse lighting from lightCount lights. Specifying true to spotLight is more expensive
// to calculate but lights are treated as spot lights otherwise they are treated as point lights. 计算所有光源产生的漫反射效果
float3 ShadeVertexLightsFull (float4 vertex, float3 normal, int lightCount, bool spotLight)
{
    float3 viewpos = UnityObjectToViewPos (vertex.xyz);     // 顶点转换到观察空间
    float3 viewN = normalize (mul ((float3x3)UNITY_MATRIX_IT_MV, normal));  // 法线需要右乘逆转置矩阵

    float3 lightColor = UNITY_LIGHTMODEL_AMBIENT.xyz;   // 初始光照颜色为环境光
    for (int i = 0; i < lightCount; i++) {
        float3 toLight = unity_LightPosition[i].xyz - viewpos.xyz * unity_LightPosition[i].w; // 方向光w为0，非方向光w为1
        float lengthSq = dot(toLight, toLight);

        // don't produce NaNs if some vertex position overlaps with the light
        lengthSq = max(lengthSq, 0.000001);

        toLight *= rsqrt(lengthSq);

        float atten = 1.0 / (1.0 + lengthSq * unity_LightAtten[i].z);   // UnityShaderVariabls.cginc: L129~L133
        if (spotLight)
        { // 聚光灯计算原理: https://zhuanlan.zhihu.com/p/150570369
            float rho = max (0, dot(toLight, unity_SpotDirection[i].xyz));  // toLight与unity_SportDirection方向夹角的余弦值，cos(p)
            float spotAtt = (rho - unity_LightAtten[i].x) * unity_LightAtten[i].y;  // [cos(p) - cos(angle / 2)] / [cos(angle / 4) - cos(angle/2)]
            atten *= saturate(spotAtt);     // 确保衰减系统在[0, 1]范围内, 顶点与聚光灯夹角在1/4张角内时，不存在衰减，为1；大于1/2张角时，衰减成0
        }

        float diff = max (0, dot (viewN, toLight));     // Lambert Lighting
        lightColor += unity_LightColor[i].rgb * (diff * atten);
    }
    return lightColor;
}
// 对指定4个非聚光灯光源进行光照计算（聚光灯的计算消耗较高）
float3 ShadeVertexLights (float4 vertex, float3 normal)
{
    return ShadeVertexLightsFull (vertex, normal, 4, false);
}

// normal should be normalized, w=1.0
half3 SHEvalLinearL0L1 (half4 normal)
{
    half3 x;

    // Linear (L1) + constant (L0) polynomial terms
    x.r = dot(unity_SHAr,normal);
    x.g = dot(unity_SHAg,normal);
    x.b = dot(unity_SHAb,normal);

    return x;
}

// normal should be normalized, w=1.0
half3 SHEvalLinearL2 (half4 normal)
{
    half3 x1, x2;
    // 4 of the quadratic (L2) polynomials
    half4 vB = normal.xyzz * normal.yzzx;
    x1.r = dot(unity_SHBr,vB);
    x1.g = dot(unity_SHBg,vB);
    x1.b = dot(unity_SHBb,vB);

    // Final (5th) quadratic (L2) polynomial
    half vC = normal.x*normal.x - normal.y*normal.y;
    x2 = unity_SHC.rgb * vC;

    return x1 + x2;
}

// normal should be normalized, w=1.0
// output in active color space
half3 ShadeSH9 (half4 normal)
{
    // Linear + constant polynomial terms
    half3 res = SHEvalLinearL0L1 (normal);

    // Quadratic polynomials
    res += SHEvalLinearL2 (normal);

#   ifdef UNITY_COLORSPACE_GAMMA
        res = LinearToGammaSpace (res);
#   endif

    return res;
}

// OBSOLETE: for backwards compatibility with 5.0
half3 ShadeSH3Order(half4 normal)
{
    // Quadratic polynomials
    half3 res = SHEvalLinearL2 (normal);

#   ifdef UNITY_COLORSPACE_GAMMA
        res = LinearToGammaSpace (res);
#   endif

    return res;
}

#if UNITY_LIGHT_PROBE_PROXY_VOLUME

// normal should be normalized, w=1.0
half3 SHEvalLinearL0L1_SampleProbeVolume (half4 normal, float3 worldPos)
{
    const float transformToLocal = unity_ProbeVolumeParams.y;
    const float texelSizeX = unity_ProbeVolumeParams.z;

    //The SH coefficients textures and probe occlusion are packed into 1 atlas.
    //-------------------------
    //| ShR | ShG | ShB | Occ |
    //-------------------------

    float3 position = (transformToLocal == 1.0f) ? mul(unity_ProbeVolumeWorldToObject, float4(worldPos, 1.0)).xyz : worldPos;
    float3 texCoord = (position - unity_ProbeVolumeMin.xyz) * unity_ProbeVolumeSizeInv.xyz;
    texCoord.x = texCoord.x * 0.25f;

    // We need to compute proper X coordinate to sample.
    // Clamp the coordinate otherwize we'll have leaking between RGB coefficients
    float texCoordX = clamp(texCoord.x, 0.5f * texelSizeX, 0.25f - 0.5f * texelSizeX);

    // sampler state comes from SHr (all SH textures share the same sampler)
    texCoord.x = texCoordX;
    half4 SHAr = UNITY_SAMPLE_TEX3D_SAMPLER(unity_ProbeVolumeSH, unity_ProbeVolumeSH, texCoord);

    texCoord.x = texCoordX + 0.25f;
    half4 SHAg = UNITY_SAMPLE_TEX3D_SAMPLER(unity_ProbeVolumeSH, unity_ProbeVolumeSH, texCoord);

    texCoord.x = texCoordX + 0.5f;
    half4 SHAb = UNITY_SAMPLE_TEX3D_SAMPLER(unity_ProbeVolumeSH, unity_ProbeVolumeSH, texCoord);

    // Linear + constant polynomial terms
    half3 x1;
    x1.r = dot(SHAr, normal);
    x1.g = dot(SHAg, normal);
    x1.b = dot(SHAb, normal);

    return x1;
}
#endif

// normal should be normalized, w=1.0
half3 ShadeSH12Order (half4 normal)
{
    // Linear + constant polynomial terms
    half3 res = SHEvalLinearL0L1 (normal);

#   ifdef UNITY_COLORSPACE_GAMMA
        res = LinearToGammaSpace (res);
#   endif

    return res;
}

// Transforms 2D UV by scale/bias property 定义四维向量，xy表示Tiling，zw表示offsset
#define TRANSFORM_TEX(tex,name) (tex.xy * name##_ST.xy + name##_ST.zw)  // 坐标：uv * tiling + offset

// Deprecated. Used to transform 4D UV by a fixed function texture matrix. Now just returns the passed UV.
#define TRANSFORM_UV(idx) v.texcoord.xy


// 定义顶点光照结构体，实现最低保真度的光照且不支持实时阴影的渲染途径
struct v2f_vertex_lit {
    float2 uv   : TEXCOORD0;    // 纹理坐标
    fixed4 diff : COLOR0;       // 漫反射颜色
    fixed4 spec : COLOR1;       // 镜面反射颜色
};

inline fixed4 VertexLight( v2f_vertex_lit i, sampler2D mainTex )
{
    fixed4 texcol = tex2D( mainTex, i.uv );
    fixed4 c;
    c.xyz = ( texcol.xyz * i.diff.xyz + i.spec.xyz * texcol.a );    // 漫反射颜色*纹理颜色 + 镜面反射颜色*纹理alpha
    c.w = texcol.w * i.diff.w;  // alpha为纹理alpha*漫反射的alpha
    return c;
}


// Calculates UV offset for parallax bump mapping 计算视差纹理的uv偏移
inline float2 ParallaxOffset( half h, half height, half3 viewDir )
{
    h = h * height - height/2.0;
    float3 v = normalize(viewDir);
    v.z += 0.42;
    return h * (v.xy / v.z);
}

// Converts color to luminance (grayscale) 将颜色转换成亮度值（灰度值）
inline half Luminance(half3 rgb)
{
    return dot(rgb, unity_ColorSpaceLuminance.rgb); 
}

// Convert rgb to luminance 把线性空间中的RGB转换成亮度值。 RGB ===>>> CIE1931-Yxy
// with rgb in linear space with sRGB primaries and D65 white point
half LinearRgbToLuminance(half3 linearRgb)
{
    return dot(linearRgb, half3(0.2126729f,  0.7151522f, 0.0721750f));  // Y = 0.2126729 * R + 0.7151522 * G + 0.0721750 * B
}
// 将原颜色转换成RGBM编码，HDRM/LogLUV颜色编码格式：https://graphicrants.blogspot.com/2009/04/rgbm-color-encoding.html
half4 UnityEncodeRGBM (half3 color, float maxRGBM) // 如(0.1, 0.2, 0.5), 4
{
    float kOneOverRGBMMaxRange = 1.0 / maxRGBM;     // 定义一个最大的范围maxRGBM，整个颜色的范围在[0, maxRGBM]之间  （0.25）
    const float kMinMultiplier = 2.0 * 1e-2;

    float3 rgb = color * kOneOverRGBMMaxRange;  // 颜色值除maxRGBM (0.025, 0.05, 0.1)
    float alpha = max(max(rgb.r, rgb.g), max(rgb.b, kMinMultiplier));   // 找出rgb中最大的值 (0.1)
    alpha = ceil(alpha * 255.0) / 255.0;    // 最大的值向上取整  (0.10196)

    // Division-by-zero warning from d3d9, so make compiler happy.
    alpha = max(alpha, kMinMultiplier);

    return half4(rgb / alpha, alpha);   // 计算RGBM的值   (0.24519, 0.49038, 0.9807, 0.10196)
}

// Decodes HDR textures 解码HDR
// handles dLDR, RGBM formats，可处理dLDR和RGBM格式，dLDR（double low dynamic range）双重低动态范围，将[0,2]范围的亮度值到[0,1]上
inline half3 DecodeHDR (half4 data, half4 decodeInstructions)
{
    // Take into account texture alpha if decodeInstructions.w is true(the alpha value affects the RGB channels)
    half alpha = decodeInstructions.w * (data.a - 1.0) + 1.0;   // 如果w分量为1，则data.alpha为纹理的alpha值，否则alpha为1

    // If Linear mode is not supported we can skip exponent part
    #if defined(UNITY_COLORSPACE_GAMMA)
        return (decodeInstructions.x * alpha) * data.rgb;
    #else    // Linear空间
    #   if defined(UNITY_USE_NATIVE_HDR)
            return decodeInstructions.x * data.rgb; // Multiplier for future HDRI relative to absolute conversion.
    #   else
            return (decodeInstructions.x * pow(alpha, decodeInstructions.y)) * data.rgb;
    #   endif
    #endif
}

// Decodes HDR textures 将RGBM颜色解码成一个每通道8位的RGB颜色
// handles RGBM formats
inline half3 DecodeLightmapRGBM (half4 data, half4 decodeInstructions)
{
    // If Linear mode is not supported we can skip exponent part
    #if defined(UNITY_COLORSPACE_GAMMA)  // gamma空间 unity_Lightmap_HDR = (5.0, 1.0, 0.0, 0.0)
    # if defined(UNITY_FORCE_LINEAR_READ_FOR_RGBM)
        return (decodeInstructions.x * data.a) * sqrt(data.rgb);    // 在gamma空间解码线性空间的颜色
    # else
        return (decodeInstructions.x * data.a) * data.rgb;  // 解码颜色
    # endif
    #else   // Linear空间  unity_Lightmap_HDR = (pow(5.0, 2.2), 2.2, 0.0, 0.0)  pow(5.0, 2.2) = 34.49
        return (decodeInstructions.x * pow(data.a, decodeInstructions.y)) * data.rgb;
    #endif
}

// Decodes doubleLDR encoded lightmaps.
inline half3 DecodeLightmapDoubleLDR( fixed4 color, half4 decodeInstructions)
{   // unity_Lightmap_HDR = Gamma (2.0, 1.0, 0.0, 0.0) / Linear (4.59, 1.0, 0.0, 0.0)
    // decodeInstructions.x contains 2.0 when gamma color space is used or pow(2.0, 2.2) = 4.59 when linear color space is used on mobile platforms
    return decodeInstructions.x * color.rgb;
}
// 解码Lightmap有三个预定义的宏分支
inline half3 DecodeLightmap( fixed4 color, half4 decodeInstructions)
{
#if defined(UNITY_LIGHTMAP_DLDR_ENCODING)   // 使用DLDR格式解码
    return DecodeLightmapDoubleLDR(color, decodeInstructions);  // L540
#elif defined(UNITY_LIGHTMAP_RGBM_ENCODING) // 使用RGBM格式解码
    return DecodeLightmapRGBM(color, decodeInstructions); // L525
#else //defined(UNITY_LIGHTMAP_FULL_HDR) 当启用标准HDR时直接返回rgb不做额外处理
    return color.rgb;   // unity_Lightmap_HDR = (1.0, 1.0, 0.0, 0.0)
#endif
}

half4 unity_Lightmap_HDR;   // 不同预定义有不同的值，应用着以上各个函数的decodeInstructions

inline half3 DecodeLightmap( fixed4 color )
{
    return DecodeLightmap( color, unity_Lightmap_HDR );
}

half4 unity_DynamicLightmap_HDR;    // 动态的LightMap，其他同上

// Decodes Enlighten RGBM encoded lightmaps 对实时生成的光照贴图进行解码
// NOTE: Enlighten dynamic texture RGBM format is _different_ from standard Unity HDR textures 格式不同于一般的unity HDR纹理
// (such as Baked Lightmaps, Reflection Probes and IBL images) 例如，烘焙式光贴图、反射用光探针、还有IBL图像等
// Instead Enlighten provides RGBM texture in _Linear_ color space with _different_ exponent. Englithen渲染器的RGBM格式纹理是在Linear空间中定义的，使用了不同的指数操作
// WARNING: 3 pow operations, might be very expensive for mobiles!
inline half3 DecodeRealtimeLightmap( fixed4 color )
{
    //@TODO: Temporary until Geomerics gives us an API to convert lightmaps to RGBM in gamma space on the enlighten thread before we upload the textures.
#if defined(UNITY_FORCE_LINEAR_READ_FOR_RGBM)
    return pow ((unity_DynamicLightmap_HDR.x * color.a) * sqrt(color.rgb), unity_DynamicLightmap_HDR.y);
#else
    return pow ((unity_DynamicLightmap_HDR.x * color.a) * color.rgb, unity_DynamicLightmap_HDR.y);
#endif
}
// 解码方向光贴图
inline half3 DecodeDirectionalLightmap (half3 color, fixed4 dirTex, half3 normalWorld)  // 颜色、方向纹理采样点，法线
{
    // In directional (non-specular) mode Enlighten bakes dominant light direction 定向光照贴图，是原始光照贴图的增强实现
    // in a way, that using it for half Lambert and then dividing by a "rebalancing coefficient" 在某种程度上，使用半兰勃特除以方向性的系数得到近似的漫反射映射
    // gives a result close to plain diffuse response lightmaps, but normalmapped. 

    // Note that dir is not unit length on purpose. Its length is "directionality", like
    // for the directional specular lightmaps.

    half halfLambert = dot(normalWorld, dirTex.xyz - 0.5) + 0.5;    // 半Lambert

    return color * halfLambert / max(1e-4h, dirTex.w);  // w分量用来控制该点上辐射入射度的方向性，即被dominant方向影响的程度
}

// Encoding/decoding [0..1) floats into 8 bit/channel RGBA. Note that 1.0 will not be encoded properly. 把[0..1)内的浮点数编码成一个float4类型的RGBA值
inline float4 EncodeFloatRGBA( float v )
{
    float4 kEncodeMul = float4(1.0, 255.0, 65025.0, 16581375.0);
    float kEncodeBit = 1.0/255.0;
    float4 enc = kEncodeMul * v;
    enc = frac (enc);   // 只保留整数部分
    enc -= enc.yzww * kEncodeBit;
    return enc;
}
inline float DecodeFloatRGBA( float4 enc )  // 把一个float4类型的RGBA纹素值解码成一个float类型的浮点数
{
    float4 kDecodeDot = float4(1.0, 1/255.0, 1/65025.0, 1/16581375.0);
    return dot( enc, kDecodeDot );
}

// Encoding/decoding [0..1) floats into 8 bit/channel RG. Note that 1.0 will not be encoded properly. 只计算GB两个通道
inline float2 EncodeFloatRG( float v )
{
    float2 kEncodeMul = float2(1.0, 255.0);
    float kEncodeBit = 1.0/255.0;
    float2 enc = kEncodeMul * v;
    enc = frac (enc);
    enc.x -= enc.y * kEncodeBit;
    return enc;
}
inline float DecodeFloatRG( float2 enc )
{
    float2 kDecodeDot = float2(1.0, 1/255.0);
    return dot( enc, kDecodeDot );
}


// Encoding/decoding view space normals into 2D 0..1 vector 使用球极算法将观察空间的法线转换成2D的纹理坐标
inline float2 EncodeViewNormalStereo( float3 n )
{
    float kScale = 1.7777;      // 16:9
    float2 enc;
    enc = n.xy / (n.z+1);  // (X,Y) = (x/(z+1), y/(z+1))
    enc /= kScale;
    enc = enc*0.5+0.5;  // [-1, 1] ==> [0,1]
    return enc;
}
inline float3 DecodeViewNormalStereo( float4 enc4 )
{
    float kScale = 1.7777;
    float3 nn = enc4.xyz*float3(2*kScale,2*kScale,0) + float3(-kScale,-kScale,1);
    float g = 2.0 / dot(nn.xyz,nn.xyz);
    float3 n;
    n.xy = g*nn.xy;
    n.z = g-1;
    return n;
}
// 把float3类型的法线编码转到float4类型的前两个分量xy，把深度值编码进后两分量zw
inline float4 EncodeDepthNormal( float depth, float3 normal )
{
    float4 enc;
    enc.xy = EncodeViewNormalStereo (normal);
    enc.zw = EncodeFloatRG (depth);
    return enc;
}

inline void DecodeDepthNormal( float4 enc, out float depth, out float3 normal )
{
    depth = DecodeFloatRG (enc.zw);
    normal = DecodeViewNormalStereo (enc);
}
// 解码DXT5nm格式的法线贴图
inline fixed3 UnpackNormalDXT5nm (fixed4 packednormal)
{
    fixed3 normal;
    normal.xy = packednormal.wy * 2 - 1;
    normal.z = sqrt(1 - saturate(dot(normal.xy, normal.xy)));
    return normal;
}

// Unpack normal as DXT5nm (1, y, 1, x) or BC5 (x, y, 0, 1) 可以同时解码DXT5nm和BC5两种格式的法线贴图
// Note neutral texture like "bump" is (0, 0, 1, 1) to work with both plain RGB normal and DXT5nm/BC5
fixed3 UnpackNormalmapRGorAG(fixed4 packednormal)
{
    // This do the trick
   packednormal.x *= packednormal.w;    // 无论哪种格式，x都是最终的扰动向量的x

    fixed3 normal;
    normal.xy = packednormal.xy * 2 - 1;    // [0, 1] ==>> [-1, 1]
    normal.z = sqrt(1 - saturate(dot(normal.xy, normal.xy)));   // z = sqrt(1 - x^2 - y^2)，当x^2+y^2>=0时z=0，否则z=1
    return normal;
}
inline fixed3 UnpackNormal(fixed4 packednormal) // 解码法线纹理
{
#if defined(UNITY_NO_DXT5nm) // 无需解码
    return packednormal.xyz * 2 - 1;    // [0, 1] ==>> [-1, 1]
#else   // 需要解码
    return UnpackNormalmapRGorAG(packednormal);
#endif
}
// 解码法线纹理并缩放扰动
fixed3 UnpackNormalWithScale(fixed4 packednormal, float scale)
{
#ifndef UNITY_NO_DXT5nm
    // Unpack normal as DXT5nm (1, y, 1, x) or BC5 (x, y, 0, 1)
    // Note neutral texture like "bump" is (0, 0, 1, 1) to work with both plain RGB normal and DXT5nm/BC5
    packednormal.x *= packednormal.w;
#endif
    fixed3 normal;
    normal.xy = (packednormal.xy * 2 - 1) * scale;
    normal.z = sqrt(1 - saturate(dot(normal.xy, normal.xy)));
    return normal;
}

// Z buffer to linear 0..1 depth 从深度纹理中取得顶点深度值z，变换至观察空间中，然后映射到[0,1]区间内
inline float Linear01Depth( float z )
{
    return 1.0 / (_ZBufferParams.x * z + _ZBufferParams.y);     // UnityShaderVariables.cginc，L76
}
// Z buffer to linear depth 从深度纹理中取得顶点深度值z，变换至观察空间中，然后映射到[0,1]区间内
inline float LinearEyeDepth( float z )
{
    return 1.0 / (_ZBufferParams.z * z + _ZBufferParams.w);
}

// 使用Graphics.Blit()进行后期处理效果时，如果启用了单程立体渲染，Blit中的纹理采样器不能自动地在由两个左右眼图像合并而成的可渲染纹理中进行定位采样，所以需要告诉着色器左右眼采样的修正
inline float2 UnityStereoScreenSpaceUVAdjustInternal(float2 uv, float4 scaleAndOffset)    // scaleAndOffset: xy是缩放，zw是偏移，float4的采样器变量需要加上"_ST"
{
    return uv.xy * scaleAndOffset.xy + scaleAndOffset.zw;
}

inline float4 UnityStereoScreenSpaceUVAdjustInternal(float4 uv, float4 scaleAndOffset) // 处理两组坐标
{
    return float4(UnityStereoScreenSpaceUVAdjustInternal(uv.xy, scaleAndOffset), UnityStereoScreenSpaceUVAdjustInternal(uv.zw, scaleAndOffset));
}

#define UnityStereoScreenSpaceUVAdjust(x, y) UnityStereoScreenSpaceUVAdjustInternal(x, y)
// 对单程立体渲染用到的左右眼图像，放到一张可渲染纹理的左右两边时要做的缩放和偏移操作，UnityShaderVariables.cginc,L 195
#if defined(UNITY_SINGLE_PASS_STEREO)
float2 TransformStereoScreenSpaceTex(float2 uv, float w)
{
    float4 scaleOffset = unity_StereoScaleOffset[unity_StereoEyeIndex];
    return uv.xy * scaleOffset.xy + scaleOffset.zw * w;
}
// 对立体渲染时左右眼离屏纹理的形变操作
inline float2 UnityStereoTransformScreenSpaceTex(float2 uv)
{
    return TransformStereoScreenSpaceTex(saturate(uv), 1.0);
}

inline float4 UnityStereoTransformScreenSpaceTex(float4 uv) // 处理两组坐标
{
    return float4(UnityStereoTransformScreenSpaceTex(uv.xy), UnityStereoTransformScreenSpaceTex(uv.zw));
}
inline float2 UnityStereoClamp(float2 uv, float4 scaleAndOffset)    // scaleAndOffset: xy是缩放，zw是偏移
{
    return float2(clamp(uv.x, scaleAndOffset.z, scaleAndOffset.z + scaleAndOffset.x), uv.y);
}
#else   // 如果不使用单程立体渲染，则前面定义的函数不做操作
#define TransformStereoScreenSpaceTex(uv, w) uv
#define UnityStereoTransformScreenSpaceTex(uv) uv
#define UnityStereoClamp(uv, scaleAndOffset) uv
#endif

// Depth render texture helpers 深度纹理Helper
#define DECODE_EYEDEPTH(i) LinearEyeDepth(i)    // 从深度纹理中取得顶点深度值z，变换至观察空间中，然后映射到[0,1]区间内
#define COMPUTE_EYEDEPTH(o) o = -UnityObjectToViewPos( v.vertex ).z // 取得顶点从世界空间变换到观察空间后的z值，并且取其相反数
#define COMPUTE_DEPTH_01 -(UnityObjectToViewPos( v.vertex ).z * _ProjectionParams.w) // 取得顶点从世界空间变换到观察空间后的z值，并且取其相反数后映射到[0,1]范围内
#define COMPUTE_VIEW_NORMAL normalize(mul((float3x3)UNITY_MATRIX_IT_MV, v.normal))  // 把顶点法线从世界空间变换到观察空间

// Helpers used in image effects. Most image effects use the same
// minimal vertex shader (vert_img).
// 顶点着色器：简单的顶点描述结构体
struct appdata_img
{
    float4 vertex : POSITION;       // 顶点的齐次化位置坐标
    half2 texcoord : TEXCOORD0;     // 顶点用到的第一层纹理坐标
    UNITY_VERTEX_INPUT_INSTANCE_ID  // 硬件instance id
};
// 片元着色器：简单的片元描述结构体
struct v2f_img
{
    float4 pos : SV_POSITION;       // 要传递给片元着色器的顶点坐标，裁剪空间
    half2 uv : TEXCOORD0;           // 用到的第一层纹理映射坐标
    UNITY_VERTEX_INPUT_INSTANCE_ID  //  硬件instance id
    UNITY_VERTEX_OUTPUT_STEREO      // 立体渲染时的左右眼索引，UnityInstancing.cginc,L153
};
// 把纹理坐标从一个空间变换到另一个空间
float2 MultiplyUV (float4x4 mat, float2 inUV) {
    float4 temp = float4 (inUV.x, inUV.y, 0, 0);
    temp = mul (mat, temp);
    return temp.xy;
}
// 顶点着色
v2f_img vert_img( appdata_img v )
{
    v2f_img o;
    UNITY_INITIALIZE_OUTPUT(v2f_img, o);    // 初始化结构体
    UNITY_SETUP_INSTANCE_ID(v);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

    o.pos = UnityObjectToClipPos (v.vertex);    // 顶点坐标从模型空间转换到裁剪空间
    o.uv = v.texcoord;      // 第一层纹理映射坐标
    return o;
}

// Projected screen position helpers
#define V2F_SCREEN_TYPE float4
// 计算非立体渲染时的"屏幕坐标"(并不是屏幕上的点，返回的结果需要在片元着色器中进行透视除法，除以w，再乘以屏幕宽高，才能得到屏幕坐标)
inline float4 ComputeNonStereoScreenPos(float4 pos) {   // pos是裁剪空间下的坐标，x,y还未除以w之前
    float4 o = pos * 0.5f;  // (x/2, y/2, z/2, w/2)
    o.xy = float2(o.x, o.y*_ProjectionParams.x) + o.w;      //ProjectionParams.x: 1 or -1 (-1 if projection is flipped)    投影是否翻转
    o.zw = pos.zw;
    return o;   // (x/2 + w/2, y/2 +- w/2, z, w)；屏幕坐标uv = o.xy / o.w * screen.size;
}
// 从裁剪齐次坐标计算屏幕坐标
inline float4 ComputeScreenPos(float4 pos) {
    float4 o = ComputeNonStereoScreenPos(pos);          // 非立体渲染
#if defined(UNITY_SINGLE_PASS_STEREO)
    o.xy = TransformStereoScreenSpaceTex(o.xy, pos.w);  // 立体渲染
#endif
    return o;
}
// 把当前屏幕内容截屏并保存在一个目标纹理时，需要知道在裁剪空间中的某一个点对应保存在目标纹理中的哪一个点
inline float4 ComputeGrabScreenPos (float4 pos) {
    #if UNITY_UV_STARTS_AT_TOP  // DX屏幕坐标系
    float scale = -1.0;
    #else   // GL屏幕坐标系
    float scale = 1.0;
    #endif
    float4 o = pos * 0.5f;
    o.xy = float2(o.x, o.y*scale) + o.w;
#ifdef UNITY_SINGLE_PASS_STEREO
    o.xy = TransformStereoScreenSpaceTex(o.xy, pos.w);
#endif
    o.zw = pos.zw;
    return o;
}

// snaps post-transformed position to screen pixels 将视口坐标(ComputeScreenPos)转换成屏幕像素坐标
inline float4 UnityPixelSnap (float4 pos)
{
    float2 hpc = _ScreenParams.xy * 0.5f;
#if  SHADER_API_PSSL
// An old sdk used to implement round() as floor(x+0.5) current sdks use the round to even method so we manually use the old method here for compatabilty.
    float2 temp = ((pos.xy / pos.w) * hpc) + float2(0.5f,0.5f);
    float2 pixelPos = float2(floor(temp.x), floor(temp.y));
#else
    float2 pixelPos = round ((pos.xy / pos.w) * hpc);
#endif
    pos.xy = pixelPos / hpc * pos.w;
    return pos;
}
// 从观察空间转换到裁剪空间
inline float2 TransformViewToProjection (float2 v) {
    return mul((float2x2)UNITY_MATRIX_P, v);
}
// 从观察空间转换到裁剪空间
inline float3 TransformViewToProjection (float3 v) {
    return mul((float3x3)UNITY_MATRIX_P, v);
}

// Shadow caster pass helpers 阴影处理相关的工具函数
// 把一个float类型的阴影深度值编码进一个float4的RGBA颜色中，点光源的作用深度被存储在一个CubeMap中
float4 UnityEncodeCubeShadowDepth (float z)
{
    #ifdef UNITY_USE_RGBA_FOR_POINT_SHADOWS
    return EncodeFloatRGBA (min(z, 0.999));
    #else
    return z;
    #endif
}
// 把一个float4类型的阴影颜色值解码成float类型的深度值
float UnityDecodeCubeShadowDepth (float4 vals)
{
    #ifdef UNITY_USE_RGBA_FOR_POINT_SHADOWS
    return DecodeFloatRGBA (vals);
    #else
    return vals.r;
    #endif
}

// 将阴影投射者的坐标沿着法线做一定偏移后再变换至裁剪空间
float4 UnityClipSpaceShadowCasterPos(float4 vertex, float3 normal)
{
    float4 wPos = mul(unity_ObjectToWorld, vertex);

    if (unity_LightShadowBias.z != 0.0)
    {
        float3 wNormal = UnityObjectToWorldNormal(normal);
        float3 wLight = normalize(UnityWorldSpaceLightDir(wPos.xyz));

        // apply normal offset bias (inset position along the normal)
        // bias needs to be scaled by sine between normal and light direction
        // (http://the-witness.net/news/2013/09/shadow-mapping-summary-part-1/)
        //
        // unity_LightShadowBias.z contains user-specified normal offset amount
        // scaled by world space texel size.

        float shadowCos = dot(wNormal, wLight);
        float shadowSine = sqrt(1-shadowCos*shadowCos); // 计算正弦值
        float normalBias = unity_LightShadowBias.z * shadowSine;    // UnityShaderVariables.cginc, L160

        wPos.xyz -= wNormal * normalBias;   // 沿法线进行偏移
    }

    return mul(UNITY_MATRIX_VP, wPos);
}
// Legacy, not used anymore; kept around to not break existing user shaders
float4 UnityClipSpaceShadowCasterPos(float3 vertex, float3 normal)
{
    return UnityClipSpaceShadowCasterPos(float4(vertex, 1), normal);
}

// 将裁剪空间坐标的z值再做一定的偏移
float4 UnityApplyLinearShadowBias(float4 clipPos)

{
    // For point lights that support depth cube map, the bias is applied in the fragment shader sampling the shadow map.
    // This is because the legacy behaviour for point light shadow map cannot be implemented by offseting the vertex position
    // in the vertex shader generating the shadow map.
#if !(defined(SHADOWS_CUBE) && defined(SHADOWS_CUBE_IN_DEPTH_TEX))
    #if defined(UNITY_REVERSED_Z)
        // We use max/min instead of clamp to ensure proper handling of the rare case
        // where both numerator and denominator are zero and the fraction becomes NaN.
        clipPos.z += max(-1, min(unity_LightShadowBias.x / clipPos.w, 0));
    #else
        clipPos.z += saturate(unity_LightShadowBias.x/clipPos.w);
    #endif
#endif

#if defined(UNITY_REVERSED_Z)
    float clamped = min(clipPos.z, clipPos.w*UNITY_NEAR_CLIP_VALUE);
#else
    float clamped = max(clipPos.z, clipPos.w*UNITY_NEAR_CLIP_VALUE);
#endif
    clipPos.z = lerp(clipPos.z, clamped, unity_LightShadowBias.y);
    return clipPos;
}


#if defined(SHADOWS_CUBE) && !defined(SHADOWS_CUBE_IN_DEPTH_TEX)
    // Rendering into point light (cubemap) shadows
    #define V2F_SHADOW_CASTER_NOPOS float3 vec : TEXCOORD0; // 存储在世界坐标系下当前顶点到光源位置的连线向量
    #define TRANSFER_SHADOW_CASTER_NOPOS_LEGACY(o,opos) o.vec = mul(unity_ObjectToWorld, v.vertex).xyz - _LightPositionRange.xyz; opos = UnityObjectToClipPos(v.vertex);
    #define TRANSFER_SHADOW_CASTER_NOPOS(o,opos) o.vec = mul(unity_ObjectToWorld, v.vertex).xyz - _LightPositionRange.xyz; opos = UnityObjectToClipPos(v.vertex);
    #define SHADOW_CASTER_FRAGMENT(i) return UnityEncodeCubeShadowDepth ((length(i.vec) + unity_LightShadowBias.x) * _LightPositionRange.w);

#else
    // Rendering into directional or spot light shadows
    #define V2F_SHADOW_CASTER_NOPOS
    // Let embedding code know that V2F_SHADOW_CASTER_NOPOS is empty; so that it can workaround
    // empty structs that could possibly be produced.
    #define V2F_SHADOW_CASTER_NOPOS_IS_EMPTY
    #define TRANSFER_SHADOW_CASTER_NOPOS_LEGACY(o,opos) \
        opos = UnityObjectToClipPos(v.vertex.xyz); \
        opos = UnityApplyLinearShadowBias(opos);    
    #define TRANSFER_SHADOW_CASTER_NOPOS(o,opos) \
        opos = UnityClipSpaceShadowCasterPos(v.vertex, v.normal); \
        opos = UnityApplyLinearShadowBias(opos);
    #define SHADOW_CASTER_FRAGMENT(i) return 0;
#endif

// Declare all data needed for shadow caster pass output (any shadow directions/depths/distances as needed),
// plus clip space position.
#define V2F_SHADOW_CASTER V2F_SHADOW_CASTER_NOPOS UNITY_POSITION(pos)

// Vertex shader part, with support for normal offset shadows. Requires
// position and normal to be present in the vertex input.
#define TRANSFER_SHADOW_CASTER_NORMALOFFSET(o) TRANSFER_SHADOW_CASTER_NOPOS(o,o.pos)

// Vertex shader part, legacy. No support for normal offset shadows - because
// that would require vertex normals, which might not be present in user-written shaders.
#define TRANSFER_SHADOW_CASTER(o) TRANSFER_SHADOW_CASTER_NOPOS_LEGACY(o,o.pos)


// ------------------------------------------------------------------
//  Alpha helper

#define UNITY_OPAQUE_ALPHA(outputAlpha) outputAlpha = 1.0


// ------------------------------------------------------------------
//  Fog helpers
//
//  multi_compile_fog Will compile fog variants.
//  UNITY_FOG_COORDS(texcoordindex) Declares the fog data interpolator.
//  UNITY_TRANSFER_FOG(outputStruct,clipspacePos) Outputs fog data from the vertex shader.
//  UNITY_APPLY_FOG(fogData,col) Applies fog to color "col". Automatically applies black fog when in forward-additive pass.
//  Can also use UNITY_APPLY_FOG_COLOR to supply your own fog color.

// In case someone by accident tries to compile fog code in one of the g-buffer or shadow passes:
// treat it as fog is off.
#if defined(UNITY_PASS_PREPASSBASE) || defined(UNITY_PASS_DEFERRED) || defined(UNITY_PASS_SHADOWCASTER)
#undef FOG_LINEAR
#undef FOG_EXP
#undef FOG_EXP2
#endif

#if defined(UNITY_REVERSED_Z)
    #if UNITY_REVERSED_Z == 1
        //D3d with reversed Z => z clip range is [near, 0] -> remapping to [0, far]
        //max is required to protect ourselves from near plane not being correct/meaningfull in case of oblique matrices.
        #define UNITY_Z_0_FAR_FROM_CLIPSPACE(coord) max(((1.0-(coord)/_ProjectionParams.y)*_ProjectionParams.z),0)
    #else
        //GL with reversed z => z clip range is [near, -far] -> should remap in theory but dont do it in practice to save some perf (range is close enough)
        #define UNITY_Z_0_FAR_FROM_CLIPSPACE(coord) max(-(coord), 0)
    #endif
#elif UNITY_UV_STARTS_AT_TOP
    //D3d without reversed z => z clip range is [0, far] -> nothing to do
    #define UNITY_Z_0_FAR_FROM_CLIPSPACE(coord) (coord)
#else
    //Opengl => z clip range is [-near, far] -> should remap in theory but dont do it in practice to save some perf (range is close enough)
    #define UNITY_Z_0_FAR_FROM_CLIPSPACE(coord) (coord)
#endif

#if defined(FOG_LINEAR)
    // factor = (end-z)/(end-start) = z * (-1/(end-start)) + (end/(end-start))
    #define UNITY_CALC_FOG_FACTOR_RAW(coord) float unityFogFactor = (coord) * unity_FogParams.z + unity_FogParams.w
#elif defined(FOG_EXP)
    // factor = exp(-density*z)
    #define UNITY_CALC_FOG_FACTOR_RAW(coord) float unityFogFactor = unity_FogParams.y * (coord); unityFogFactor = exp2(-unityFogFactor)
#elif defined(FOG_EXP2)
    // factor = exp(-(density*z)^2)
    #define UNITY_CALC_FOG_FACTOR_RAW(coord) float unityFogFactor = unity_FogParams.x * (coord); unityFogFactor = exp2(-unityFogFactor*unityFogFactor)
#else
    #define UNITY_CALC_FOG_FACTOR_RAW(coord) float unityFogFactor = 0.0
#endif

#define UNITY_CALC_FOG_FACTOR(coord) UNITY_CALC_FOG_FACTOR_RAW(UNITY_Z_0_FAR_FROM_CLIPSPACE(coord))

#define UNITY_FOG_COORDS_PACKED(idx, vectype) vectype fogCoord : TEXCOORD##idx;

#if defined(FOG_LINEAR) || defined(FOG_EXP) || defined(FOG_EXP2)
    #define UNITY_FOG_COORDS(idx) UNITY_FOG_COORDS_PACKED(idx, float1)

    #if (SHADER_TARGET < 30) || defined(SHADER_API_MOBILE)
        // mobile or SM2.0: calculate fog factor per-vertex
        #define UNITY_TRANSFER_FOG(o,outpos) UNITY_CALC_FOG_FACTOR((outpos).z); o.fogCoord.x = unityFogFactor
        #define UNITY_TRANSFER_FOG_COMBINED_WITH_TSPACE(o,outpos) UNITY_CALC_FOG_FACTOR((outpos).z); o.tSpace1.y = tangentSign; o.tSpace2.y = unityFogFactor
        #define UNITY_TRANSFER_FOG_COMBINED_WITH_WORLD_POS(o,outpos) UNITY_CALC_FOG_FACTOR((outpos).z); o.worldPos.w = unityFogFactor
        #define UNITY_TRANSFER_FOG_COMBINED_WITH_EYE_VEC(o,outpos) UNITY_CALC_FOG_FACTOR((outpos).z); o.eyeVec.w = unityFogFactor
    #else
        // SM3.0 and PC/console: calculate fog distance per-vertex, and fog factor per-pixel
        #define UNITY_TRANSFER_FOG(o,outpos) o.fogCoord.x = (outpos).z
        #define UNITY_TRANSFER_FOG_COMBINED_WITH_TSPACE(o,outpos) o.tSpace2.y = (outpos).z
        #define UNITY_TRANSFER_FOG_COMBINED_WITH_WORLD_POS(o,outpos) o.worldPos.w = (outpos).z
        #define UNITY_TRANSFER_FOG_COMBINED_WITH_EYE_VEC(o,outpos) o.eyeVec.w = (outpos).z
    #endif
#else
    #define UNITY_FOG_COORDS(idx)
    #define UNITY_TRANSFER_FOG(o,outpos)
    #define UNITY_TRANSFER_FOG_COMBINED_WITH_TSPACE(o,outpos)
    #define UNITY_TRANSFER_FOG_COMBINED_WITH_WORLD_POS(o,outpos)
    #define UNITY_TRANSFER_FOG_COMBINED_WITH_EYE_VEC(o,outpos)
#endif

#define UNITY_FOG_LERP_COLOR(col,fogCol,fogFac) col.rgb = lerp((fogCol).rgb, (col).rgb, saturate(fogFac))


#if defined(FOG_LINEAR) || defined(FOG_EXP) || defined(FOG_EXP2)
    #if (SHADER_TARGET < 30) || defined(SHADER_API_MOBILE)
        // mobile or SM2.0: fog factor was already calculated per-vertex, so just lerp the color
        #define UNITY_APPLY_FOG_COLOR(coord,col,fogCol) UNITY_FOG_LERP_COLOR(col,fogCol,(coord).x)
    #else
        // SM3.0 and PC/console: calculate fog factor and lerp fog color
        #define UNITY_APPLY_FOG_COLOR(coord,col,fogCol) UNITY_CALC_FOG_FACTOR((coord).x); UNITY_FOG_LERP_COLOR(col,fogCol,unityFogFactor)
    #endif
    #define UNITY_EXTRACT_FOG(name) float _unity_fogCoord = name.fogCoord
    #define UNITY_EXTRACT_FOG_FROM_TSPACE(name) float _unity_fogCoord = name.tSpace2.y
    #define UNITY_EXTRACT_FOG_FROM_WORLD_POS(name) float _unity_fogCoord = name.worldPos.w
    #define UNITY_EXTRACT_FOG_FROM_EYE_VEC(name) float _unity_fogCoord = name.eyeVec.w
#else
    #define UNITY_APPLY_FOG_COLOR(coord,col,fogCol)
    #define UNITY_EXTRACT_FOG(name)
    #define UNITY_EXTRACT_FOG_FROM_TSPACE(name)
    #define UNITY_EXTRACT_FOG_FROM_WORLD_POS(name)
    #define UNITY_EXTRACT_FOG_FROM_EYE_VEC(name)
#endif

#ifdef UNITY_PASS_FORWARDADD
    #define UNITY_APPLY_FOG(coord,col) UNITY_APPLY_FOG_COLOR(coord,col,fixed4(0,0,0,0))
#else
    #define UNITY_APPLY_FOG(coord,col) UNITY_APPLY_FOG_COLOR(coord,col,unity_FogColor)
#endif

// ------------------------------------------------------------------
//  TBN helpers
#define UNITY_EXTRACT_TBN_0(name) fixed3 _unity_tbn_0 = name.tSpace0.xyz
#define UNITY_EXTRACT_TBN_1(name) fixed3 _unity_tbn_1 = name.tSpace1.xyz
#define UNITY_EXTRACT_TBN_2(name) fixed3 _unity_tbn_2 = name.tSpace2.xyz

#define UNITY_EXTRACT_TBN(name) UNITY_EXTRACT_TBN_0(name); UNITY_EXTRACT_TBN_1(name); UNITY_EXTRACT_TBN_2(name)

#define UNITY_EXTRACT_TBN_T(name) fixed3 _unity_tangent = fixed3(name.tSpace0.x, name.tSpace1.x, name.tSpace2.x)
#define UNITY_EXTRACT_TBN_N(name) fixed3 _unity_normal = fixed3(name.tSpace0.z, name.tSpace1.z, name.tSpace2.z)
#define UNITY_EXTRACT_TBN_B(name) fixed3 _unity_binormal = cross(_unity_normal, _unity_tangent)
#define UNITY_CORRECT_TBN_B_SIGN(name) _unity_binormal *= name.tSpace1.y;
#define UNITY_RECONSTRUCT_TBN_0 fixed3 _unity_tbn_0 = fixed3(_unity_tangent.x, _unity_binormal.x, _unity_normal.x)
#define UNITY_RECONSTRUCT_TBN_1 fixed3 _unity_tbn_1 = fixed3(_unity_tangent.y, _unity_binormal.y, _unity_normal.y)
#define UNITY_RECONSTRUCT_TBN_2 fixed3 _unity_tbn_2 = fixed3(_unity_tangent.z, _unity_binormal.z, _unity_normal.z)

#if defined(FOG_LINEAR) || defined(FOG_EXP) || defined(FOG_EXP2)
    #define UNITY_RECONSTRUCT_TBN(name) UNITY_EXTRACT_TBN_T(name); UNITY_EXTRACT_TBN_N(name); UNITY_EXTRACT_TBN_B(name); UNITY_CORRECT_TBN_B_SIGN(name); UNITY_RECONSTRUCT_TBN_0; UNITY_RECONSTRUCT_TBN_1; UNITY_RECONSTRUCT_TBN_2
#else
    #define UNITY_RECONSTRUCT_TBN(name) UNITY_EXTRACT_TBN(name)
#endif

//  LOD cross fade helpers
// keep all the old macros
#define UNITY_DITHER_CROSSFADE_COORDS
#define UNITY_DITHER_CROSSFADE_COORDS_IDX(idx)
#define UNITY_TRANSFER_DITHER_CROSSFADE(o,v)
#define UNITY_TRANSFER_DITHER_CROSSFADE_HPOS(o,hpos)

#ifdef LOD_FADE_CROSSFADE
    #define UNITY_APPLY_DITHER_CROSSFADE(vpos)  UnityApplyDitherCrossFade(vpos)
    sampler2D unity_DitherMask;
    void UnityApplyDitherCrossFade(float2 vpos)
    {
        vpos /= 4; // the dither mask texture is 4x4
        float mask = tex2D(unity_DitherMask, vpos).a;
        float sgn = unity_LODFade.x > 0 ? 1.0f : -1.0f;
        clip(unity_LODFade.x - mask * sgn);
    }
#else
    #define UNITY_APPLY_DITHER_CROSSFADE(vpos)
#endif


// ------------------------------------------------------------------
//  Deprecated things: these aren't used; kept here
//  just so that various existing shaders still compile, more or less.


// Note: deprecated shadow collector pass helpers
#ifdef SHADOW_COLLECTOR_PASS

#if !defined(SHADOWMAPSAMPLER_DEFINED)
UNITY_DECLARE_SHADOWMAP(_ShadowMapTexture);
#endif

// Note: V2F_SHADOW_COLLECTOR and TRANSFER_SHADOW_COLLECTOR are deprecated
#define V2F_SHADOW_COLLECTOR float4 pos : SV_POSITION; float3 _ShadowCoord0 : TEXCOORD0; float3 _ShadowCoord1 : TEXCOORD1; float3 _ShadowCoord2 : TEXCOORD2; float3 _ShadowCoord3 : TEXCOORD3; float4 _WorldPosViewZ : TEXCOORD4
#define TRANSFER_SHADOW_COLLECTOR(o)    \
    o.pos = UnityObjectToClipPos(v.vertex); \
    float4 wpos = mul(unity_ObjectToWorld, v.vertex); \
    o._WorldPosViewZ.xyz = wpos; \
    o._WorldPosViewZ.w = -UnityObjectToViewPos(v.vertex).z; \
    o._ShadowCoord0 = mul(unity_WorldToShadow[0], wpos).xyz; \
    o._ShadowCoord1 = mul(unity_WorldToShadow[1], wpos).xyz; \
    o._ShadowCoord2 = mul(unity_WorldToShadow[2], wpos).xyz; \
    o._ShadowCoord3 = mul(unity_WorldToShadow[3], wpos).xyz;

// Note: SAMPLE_SHADOW_COLLECTOR_SHADOW is deprecated
#define SAMPLE_SHADOW_COLLECTOR_SHADOW(coord) \
    half shadow = UNITY_SAMPLE_SHADOW(_ShadowMapTexture,coord); \
    shadow = _LightShadowData.r + shadow * (1-_LightShadowData.r);

// Note: COMPUTE_SHADOW_COLLECTOR_SHADOW is deprecated
#define COMPUTE_SHADOW_COLLECTOR_SHADOW(i, weights, shadowFade) \
    float4 coord = float4(i._ShadowCoord0 * weights[0] + i._ShadowCoord1 * weights[1] + i._ShadowCoord2 * weights[2] + i._ShadowCoord3 * weights[3], 1); \
    SAMPLE_SHADOW_COLLECTOR_SHADOW(coord) \
    float4 res; \
    res.x = saturate(shadow + shadowFade); \
    res.y = 1.0; \
    res.zw = EncodeFloatRG (1 - i._WorldPosViewZ.w * _ProjectionParams.w); \
    return res;

// Note: deprecated
#if defined (SHADOWS_SPLIT_SPHERES)
#define SHADOW_COLLECTOR_FRAGMENT(i) \
    float3 fromCenter0 = i._WorldPosViewZ.xyz - unity_ShadowSplitSpheres[0].xyz; \
    float3 fromCenter1 = i._WorldPosViewZ.xyz - unity_ShadowSplitSpheres[1].xyz; \
    float3 fromCenter2 = i._WorldPosViewZ.xyz - unity_ShadowSplitSpheres[2].xyz; \
    float3 fromCenter3 = i._WorldPosViewZ.xyz - unity_ShadowSplitSpheres[3].xyz; \
    float4 distances2 = float4(dot(fromCenter0,fromCenter0), dot(fromCenter1,fromCenter1), dot(fromCenter2,fromCenter2), dot(fromCenter3,fromCenter3)); \
    float4 cascadeWeights = float4(distances2 < unity_ShadowSplitSqRadii); \
    cascadeWeights.yzw = saturate(cascadeWeights.yzw - cascadeWeights.xyz); \
    float sphereDist = distance(i._WorldPosViewZ.xyz, unity_ShadowFadeCenterAndType.xyz); \
    float shadowFade = saturate(sphereDist * _LightShadowData.z + _LightShadowData.w); \
    COMPUTE_SHADOW_COLLECTOR_SHADOW(i, cascadeWeights, shadowFade)
#else
#define SHADOW_COLLECTOR_FRAGMENT(i) \
    float4 viewZ = i._WorldPosViewZ.w; \
    float4 zNear = float4( viewZ >= _LightSplitsNear ); \
    float4 zFar = float4( viewZ < _LightSplitsFar ); \
    float4 cascadeWeights = zNear * zFar; \
    float shadowFade = saturate(i._WorldPosViewZ.w * _LightShadowData.z + _LightShadowData.w); \
    COMPUTE_SHADOW_COLLECTOR_SHADOW(i, cascadeWeights, shadowFade)
#endif

#endif // #ifdef SHADOW_COLLECTOR_PASS


// Legacy; used to do something on platforms that had to emulate depth textures manually. Now all platforms have native depth textures.
#define UNITY_TRANSFER_DEPTH(oo)
// Legacy; used to do something on platforms that had to emulate depth textures manually. Now all platforms have native depth textures.
#define UNITY_OUTPUT_DEPTH(i) return 0



#define API_HAS_GUARANTEED_R16_SUPPORT !(SHADER_API_VULKAN || SHADER_API_GLES || SHADER_API_GLES3)

float4 PackHeightmap(float height)
{
    #if (API_HAS_GUARANTEED_R16_SUPPORT)
        return height;
    #else
        uint a = (uint)(65535.0f * height);
        return float4((a >> 0) & 0xFF, (a >> 8) & 0xFF, 0, 0) / 255.0f;
    #endif
}

float UnpackHeightmap(float4 height)
{
    #if (API_HAS_GUARANTEED_R16_SUPPORT)
        return height.r;
    #else
        return (height.r + height.g * 256.0f) / 257.0f; // (255.0f * height.r + 255.0f * 256.0f * height.g) / 65535.0f
    #endif
}

#endif // UNITY_CG_INCLUDED
