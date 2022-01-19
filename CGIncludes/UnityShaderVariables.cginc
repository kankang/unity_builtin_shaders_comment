// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

#ifndef UNITY_SHADER_VARIABLES_INCLUDED
#define UNITY_SHADER_VARIABLES_INCLUDED

#include "HLSLSupport.cginc"

#if defined (DIRECTIONAL_COOKIE) || defined (DIRECTIONAL)
#define USING_DIRECTIONAL_LIGHT
#endif

#if defined(UNITY_SINGLE_PASS_STEREO) ||    // 是否启用了单程立体渲染
    defined(UNITY_STEREO_INSTANCING_ENABLED) ||     // 判断立体多例化支持宏是否启用
    defined(UNITY_STEREO_MULTIVIEW_ENABLED)         // 多视角立体渲染
#define USING_STEREO_MATRICES
#endif

#if defined(USING_STEREO_MATRICES)      // 矩阵变换，line 177
    #define glstate_matrix_projection unity_StereoMatrixP[unity_StereoEyeIndex]     // 左、右眼的投影变换矩阵，从观察空间变换到裁剪空间
    #define unity_MatrixV unity_StereoMatrixV[unity_StereoEyeIndex]                 // 左、右眼的观察变换矩阵，从世界空间变换到观察空间
    #define unity_MatrixInvV unity_StereoMatrixInvV[unity_StereoEyeIndex]           // 左、右眼的观察变换矩阵的逆矩阵，从观察空间到世界空间
    #define unity_MatrixVP unity_StereoMatrixVP[unity_StereoEyeIndex]               // 左、右眼的观察变换矩阵与投影变换矩阵的乘积，从世界空间到裁剪空间

    #define unity_CameraProjection unity_StereoCameraProjection[unity_StereoEyeIndex]           // 左、右眼摄像机的投影变换矩阵
    #define unity_CameraInvProjection unity_StereoCameraInvProjection[unity_StereoEyeIndex]     // 左、右眼摄像机的投影变换矩阵的逆矩阵
    #define unity_WorldToCamera unity_StereoWorldToCamera[unity_StereoEyeIndex]                 // 左、右眼世界坐标系转摄像机观察坐标系的变换矩阵
    #define unity_CameraToWorld unity_StereoCameraToWorld[unity_StereoEyeIndex]                 // 左、右眼摄像机观察坐标系转世界坐标系的变换矩阵
    #define _WorldSpaceCameraPos unity_StereoWorldSpaceCameraPos[unity_StereoEyeIndex]          // 左、右眼摄像机在世界坐标系中的位置
#endif

#define UNITY_MATRIX_P glstate_matrix_projection        // 定义UNITY_MATRIX_P，从观察空间变换到裁剪空间
#define UNITY_MATRIX_V unity_MatrixV                    // 定义UNITY_MATRIX_V，从世界空间变换到观察空间
#define UNITY_MATRIX_I_V unity_MatrixInvV               // 定义UNITY_MATRIX_I_V，从观察空间变换到世界空间
#define UNITY_MATRIX_VP unity_MatrixVP                  // 定义UNITY_MATRIX_VP，从世界空间变换到裁剪空间
#define UNITY_MATRIX_M unity_ObjectToWorld              // 定义UNITY_MATRIX_M，从模型空间变换到世界空间

#define UNITY_LIGHTMODEL_AMBIENT (glstate_lightmodel_ambient * 2)       // 环境光

// 相机----------------------------------------------------------------------------


CBUFFER_START(UnityPerCamera)
    // Time (t = time since current level load) values from Unity   当时场景加载开始，经过的时间（秒）
    float4 _Time; // (t/20, t, t*2, t*3)    
    float4 _SinTime; // sin(t/8), sin(t/4), sin(t/2), sin(t)
    float4 _CosTime; // cos(t/8), cos(t/4), cos(t/2), cos(t)
    float4 unity_DeltaTime; // dt, 1/dt, smoothdt, 1/smoothdt       smoothdt: 一个平滑淡出Time.deltaTime的时间。当前Time.deltaTime和上一帧的Time.smoothDeltaTime的差值的中间值。


#if !defined(USING_STEREO_MATRICES)
    float3 _WorldSpaceCameraPos;        // 摄像机在世界坐标系中的位置
#endif

    // x = 1 or -1 (-1 if projection is flipped)    投影是否翻转
    // y = near plane   近平面
    // z = far plane    远平面
    // w = 1/far plane  
    float4 _ProjectionParams;   // 投影参数

    // x = width        屏幕宽度
    // y = height       屏幕高度
    // z = 1 + 1.0/width
    // w = 1 + 1.0/height
    float4 _ScreenParams;       // 屏幕参数

    // Values used to linearize the Z buffer (http://www.humus.name/temp/Linearize%20depth.txt)
    // x = 1-far/near
    // y = far/near
    // z = x/far
    // w = y/far
    // or in case of a reversed depth buffer (UNITY_REVERSED_Z is 1)
    // x = -1+far/near
    // y = 1
    // z = x/far
    // w = 1/far
    float4 _ZBufferParams;      // Z缓冲参数，用来把zbuffer映射到[0,1]之间

    // x = orthographic camera's width
    // y = orthographic camera's height
    // z = unused
    // w = 1.0 if camera is ortho, 0.0 if perspective
    float4 unity_OrthoParams;   // 正交参数

#if defined(STEREO_CUBEMAP_RENDER_ON)
    //x-component is the half stereo separation value, which a positive for right eye and negative for left eye. The y,z,w components are unused.
    float4 unity_HalfStereoSeparation;
#endif
CBUFFER_END


CBUFFER_START(UnityPerCameraRare)
    float4 unity_CameraWorldClipPlanes[6];  // 摄像机视锥体平面世界空间方程，分别是：左、右、底、顶、近、远

#if !defined(USING_STEREO_MATRICES)
    // Projection matrices of the camera. Note that this might be different from projection matrix
    // that is set right now, e.g. while rendering shadows the matrices below are still the projection
    // of original camera.
    float4x4 unity_CameraProjection;        // 相机的投影矩阵
    float4x4 unity_CameraInvProjection;     // 相机投影矩阵的逆矩阵
    float4x4 unity_WorldToCamera;           // 世界坐标系转相机坐标系的转换矩阵
    float4x4 unity_CameraToWorld;           // 相机坐标系转世界坐标系的转换矩阵
#endif
CBUFFER_END



// 光照----------------------------------------------------------------------------

CBUFFER_START(UnityLighting)

    #ifdef USING_DIRECTIONAL_LIGHT
    half4 _WorldSpaceLightPos0;     // 方向光的方向，不需要特别精准，half足够
    #else
    float4 _WorldSpaceLightPos0;    // 点光的位置，需要特别精准，所以使用float
    #endif

    float4 _LightPositionRange; // xyz = pos, w = 1/range
    float4 _LightProjectionParams; // for point light projection: x = zfar / (znear - zfar), y = (znear * zfar) / (znear - zfar), z=shadow bias, w=shadow scale bias

    float4 unity_4LightPosX0;       // 世界空间中四个非重要点光源的x,y,z坐标（仅限Forward Base Pass)
    float4 unity_4LightPosY0;
    float4 unity_4LightPosZ0;
    half4 unity_4LightAtten0;       // 世界空间中四个光源的衰减

    half4 unity_LightColor[8];      // 8个点光源的颜色（unity5以后可以使用8个点光源了）


    float4 unity_LightPosition[8]; // view-space vertex light positions (position,1), or (-direction,0) for directional lights.
    // x = cos(spotAngle/2) or -1 for non-spot  聚光灯：1/2张角的余弦值
    // y = 1/cos(spotAngle/4) or 1 for non-spot，聚光厅的实际计算：(1/cos(spotAngle/4) - 1/cos(sportAngle/2))的倒数，如果前者差为0，y = 1
    // z = quadratic attenuation 二次项衰减系数
    // w = range*range
    half4 unity_LightAtten[8];      // 8个点光源的衰减
    float4 unity_SpotDirection[8]; // view-space spot light directions, or (0,0,1,0) for non-spot

    // SH lighting environment      // 球谐光照方程所需的27个参数
    half4 unity_SHAr;   // rgb对应l=1时，各项Y(m)与红色光分量对应的c(m)的乘积，a对应l=0时Y(m)常数值与对应c(m)的乘积
    half4 unity_SHAg;   // 绿光分量
    half4 unity_SHAb;   // 蓝光分量
    half4 unity_SHBr;   // rgb对应l=2时，各项Y(m)与红色光分量对应的c(m)的乘积，a对应l=0时Y(m)常数值与对应c(m)的乘积
    half4 unity_SHBg;
    half4 unity_SHBb;
    half4 unity_SHC;

    // part of Light because it can be used outside of shadow distance
    fixed4 unity_OcclusionMaskSelector;     // 根据当前灯光index选择阴影遮罩对应的通道
    fixed4 unity_ProbesOcclusion;           // 光探针遮罩，通过MaterialPropertyBlock.CopyProbeOcculusionArrayFrom方法赋值
CBUFFER_END

CBUFFER_START(UnityLightingOld)
    half3 unity_LightColor0, unity_LightColor1, unity_LightColor2, unity_LightColor3; // keeping those only for any existing shaders; remove in 4.0
CBUFFER_END


// 阴影----------------------------------------------------------------------------

CBUFFER_START(UnityShadows)
    float4 unity_ShadowSplitSpheres[4];     // 用于构建层叠式（cascaded shadow map）阴影贴图时子视载体用到的包围球
    float4 unity_ShadowSplitSqRadii;        // 上述包围球半径的平方
    float4 unity_LightShadowBias;           // x = Bias；y = 聚光灯=0，平等光源=1；z=沿物体表面法线移动的偏移值（解决阴影渗漏），w=0
    float4 _LightSplitsNear;                // cascade split分割的4悠游子视截体的近平面z值
    float4 _LightSplitsFar;                 // cascade split分割的4悠游子视截体的远平面z值
    float4x4 unity_WorldToShadow[4];        // 从世界空间变换到阴影贴图空间，如果使用层叠式阴影贴图，数组各元素就表征4个阴影贴图各自所对应的阴影贴图空间
    half4 _LightShadowData;                 // x = 阴影强度；y暂未使用；z = 1 / shadow far distance；w = shadow near distance
    float4 unity_ShadowFadeCenterAndType;   // 包含阴影的中心和阴影和类型
CBUFFER_END

// 逐帧绘制参数----------------------------------------------------------------------------

CBUFFER_START(UnityPerDraw)
    float4x4 unity_ObjectToWorld;       // 局部空间转换到世界空间
    float4x4 unity_WorldToObject;       // 世界空间转换到局部空间
    float4 unity_LODFade; // x is the fade value ranging within [0,1]. y is x quantized into 16 levels
    float4 unity_WorldTransformParams; // w is usually 1.0, or -1.0 for odd-negative scale transforms
    float4 unity_RenderingLayer;
CBUFFER_END
        
#if defined(USING_STEREO_MATRICES)
GLOBAL_CBUFFER_START(UnityStereoGlobals)
    float4x4 unity_StereoMatrixP[2];            // 左、右眼的投影变换矩阵，从观察空间变换到裁剪空间
    float4x4 unity_StereoMatrixV[2];            // 左、右眼的观察变换矩阵，从世界空间变换到观察空间
    float4x4 unity_StereoMatrixInvV[2];         // 左、右眼的观察变换矩阵的逆矩阵，从观察空间到世界空间
    float4x4 unity_StereoMatrixVP[2];           // 左、右眼的观察变换矩阵与投影变换矩阵的乘积，从世界空间到裁剪空间

    float4x4 unity_StereoCameraProjection[2];       // 左、右眼摄像机的投影变换矩阵
    float4x4 unity_StereoCameraInvProjection[2];    // 左、右眼摄像机的投影变换矩阵的逆矩阵
    float4x4 unity_StereoWorldToCamera[2];          // 左、右眼世界坐标系转摄像机观察坐标系的变换矩阵
    float4x4 unity_StereoCameraToWorld[2];          // 左、右眼摄像机观察坐标系转世界坐标系的变换矩阵

    float3 unity_StereoWorldSpaceCameraPos[2];      // 左、右眼摄像机在世界坐标系中的位置

    // 进行单程立体渲染时，和普通渲染不同，并不是直接把渲染效果写入对应屏幕的颜色缓冲区，
    // 而是把渲染结果写入对应于左右眼的两个图像（Image)中，然后把两个图像合并到一张可渲染纹理中再显示。
    // unity_StereoScaleOffset维护了把两个图像合并进一张纹理中要用到的平铺值（tiling）和偏移值(offset)
    float4 unity_StereoScaleOffset[2];
GLOBAL_CBUFFER_END
#endif

#if defined(USING_STEREO_MATRICES) && defined(UNITY_STEREO_MULTIVIEW_ENABLED)
GLOBAL_CBUFFER_START(UnityStereoEyeIndices)
    float4 unity_StereoEyeIndices[2];
GLOBAL_CBUFFER_END
#endif

#if defined(UNITY_STEREO_MULTIVIEW_ENABLED) && defined(SHADER_STAGE_VERTEX) // 如果启用了多视角立体渲染
    #define unity_StereoEyeIndex UNITY_VIEWID   // 把立体渲染和左右眼索引值亦是定义别名 UNITY_VIEWID (gl_viewID)
    UNITY_DECLARE_MULTIVIEW(2); // HLSLSupport.cginc
#elif defined(UNITY_STEREO_INSTANCING_ENABLED) || defined(UNITY_STEREO_MULTIVIEW_ENABLED)   // 如果启用了立体多例化渲染
    static uint unity_StereoEyeIndex;       // 定义一个表态的当前使用的眼睛索引（运行时不可改变）
#elif defined(UNITY_SINGLE_PASS_STEREO)     // 如果启用的是单程立体渲染
    GLOBAL_CBUFFER_START(UnityStereoEyeIndex)   
        int unity_StereoEyeIndex;   //把索引值定义为int类型，并作为着色器常量缓冲区中定义的变量（运行时可改变）
    GLOBAL_CBUFFER_END
#endif

CBUFFER_START(UnityPerDrawRare)
    float4x4 glstate_matrix_transpose_modelview0;
CBUFFER_END


// 每一帧由客户端引擎传递进来的逐帧数据----------------------------------------------------------------------------

CBUFFER_START(UnityPerFrame)

    fixed4 glstate_lightmodel_ambient;       // 环境光, L37
    fixed4 unity_AmbientSky;
    fixed4 unity_AmbientEquator;
    fixed4 unity_AmbientGround;
    fixed4 unity_IndirectSpecColor;

#if !defined(USING_STEREO_MATRICES)
    float4x4 glstate_matrix_projection;         // UNITY_MATRIX_P，从观察空间变换到裁剪空间, L31
    float4x4 unity_MatrixV;                     // UNITY_MATRIX_V，从世界空间变换到观察空间, L32
    float4x4 unity_MatrixInvV;                  // UNITY_MATRIX_I_V，从观察空间变换到世界空间, L33
    float4x4 unity_MatrixVP;                    // UNITY_MATRIX_VP，从世界空间变换到裁剪空间, L34
    int unity_StereoEyeIndex;                   // 左右眼索引, L205~L214
#endif

    fixed4 unity_ShadowColor;                   // 阴影颜色
CBUFFER_END


// 雾----------------------------------------------------------------------------

CBUFFER_START(UnityFog)
    fixed4 unity_FogColor;      // 雾的颜色
    // x = density / sqrt(ln(2)), useful for Exp2 mode，用于雾化因子指数平方衰减
    // y = density / ln(2), useful for Exp mode，用于雾化因子指数衰减
    // z = -1/(end-start), useful for Linear mode，用于雾化因子线性衰减
    // w = end/(end-start), useful for Linear mode，用于雾化因子线性衰减
    float4 unity_FogParams; // 雾参数
CBUFFER_END


// 光照贴图----------------------------------------------------------------------------
// Lightmaps

// Main lightmap
UNITY_DECLARE_TEX2D_HALF(unity_Lightmap);       // 声明主光照贴图，记录直接照明下的光照信息
// Directional lightmap (always used with unity_Lightmap, so can share sampler)
UNITY_DECLARE_TEX2D_NOSAMPLER_HALF(unity_LightmapInd);      // 间接光照贴图，经常和直接光照贴图一起使用，所以共享采样
// Shadowmasks
UNITY_DECLARE_TEX2D(unity_ShadowMask);      // 声明阴影mask纹理

// Dynamic GI lightmap 全局照明光照纹理
UNITY_DECLARE_TEX2D(unity_DynamicLightmap);        // 声明动态（实时）光照贴图
UNITY_DECLARE_TEX2D_NOSAMPLER(unity_DynamicDirectionality); // 声明动态（实时）间接光照贴图
UNITY_DECLARE_TEX2D_NOSAMPLER(unity_DynamicNormal);         // 场动态(实时)法线贴图

CBUFFER_START(UnityLightmaps)
    float4 unity_LightmapST;        // 对应于静态光照贴图变量unity_Lightmap，用于tiling和offset操作
    float4 unity_DynamicLightmapST; // 对应于动态（实时）光照贴图变量unity_DynamicLightmap，用于tiling和offset操作
CBUFFER_END


// 光探针----------------------------------------------------------------------------
// Reflection Probes

UNITY_DECLARE_TEXCUBE(unity_SpecCube0);     // 声明立方体贴图
UNITY_DECLARE_TEXCUBE_NOSAMPLER(unity_SpecCube1);

CBUFFER_START(UnityReflectionProbes)
    float4 unity_SpecCube0_BoxMax;          // 反射用光探针的作用区域立方体是一个和世界坐标系坐标轴轴对齐的包围盒，最大边界值
    float4 unity_SpecCube0_BoxMin;          // 最小边界值
    float4 unity_SpecCube0_ProbePosition;   // 对应于ReflectionProbe组件中光探针的位置，是由Transform组件的Position和Box Offset属性计算而来
    half4  unity_SpecCube0_HDR;             // 反射用光探针使用的立方体贴图中包含高动态范围颜色，这允许它包含大于1的亮度值，在渲染时需要将HDR值转为RGB值

    float4 unity_SpecCube1_BoxMax;
    float4 unity_SpecCube1_BoxMin;
    float4 unity_SpecCube1_ProbePosition;
    half4  unity_SpecCube1_HDR;
CBUFFER_END


// 光照探针代理----------------------------------------------------------------------------
// Light Probe Proxy Volume

// UNITY_LIGHT_PROBE_PROXY_VOLUME is used as a shader keyword coming from tier settings and may be also disabled with nolppv pragma.
// We need to convert it to 0/1 and doing a second check for safety.
#ifdef UNITY_LIGHT_PROBE_PROXY_VOLUME
    #undef UNITY_LIGHT_PROBE_PROXY_VOLUME
    // Requires quite modern graphics support (3D float textures with filtering)
    // Note: Keep this in synch with the list from LightProbeProxyVolume::HasHardwareSupport && SurfaceCompiler::IsLPPVAvailableForAnyTargetPlatform
    #if !defined(UNITY_NO_LPPV) && (defined (SHADER_API_D3D11) || defined (SHADER_API_D3D12) || defined (SHADER_API_GLCORE) || defined (SHADER_API_PSSL) || defined(SHADER_API_VULKAN) || defined(SHADER_API_METAL) || defined(SHADER_API_SWITCH))
        #define UNITY_LIGHT_PROBE_PROXY_VOLUME 1
    #else
        #define UNITY_LIGHT_PROBE_PROXY_VOLUME 0
    #endif
#else
    #define UNITY_LIGHT_PROBE_PROXY_VOLUME 0
#endif

#if UNITY_LIGHT_PROBE_PROXY_VOLUME      // 某些平台不支持LPPV
    UNITY_DECLARE_TEX3D_FLOAT(unity_ProbeVolumeSH);     // 声明光探针代理体的球谐贴图

    CBUFFER_START(UnityProbeVolume)
        // x = Disabled(0)/Enabled(1) 0:不启用，1：启用本光照体代理体
        // y = Computation are done in global space(0) or local space(1) 0: 在世界空间中计算，1:在代理体模型空间中计算
        // z = Texel size on U texture coordinate   表示体积纹理的宽度方向上纹素的大小（uv，纹素数的倒数）
        float4 unity_ProbeVolumeParams;     // 光探针代理体参数

        float4x4 unity_ProbeVolumeWorldToObject;    // 从世界空间转换到光探针代理体的变换矩阵
        float3 unity_ProbeVolumeSizeInv;            // 光探针代理体长宽高的倒数
        float3 unity_ProbeVolumeMin;                // 光探针代理体左下角的x,y,z坐标
    CBUFFER_END
#endif

static float4x4 unity_MatrixMVP = mul(unity_MatrixVP, unity_ObjectToWorld);
static float4x4 unity_MatrixMV = mul(unity_MatrixV, unity_ObjectToWorld);
static float4x4 unity_MatrixTMV = transpose(unity_MatrixMV);
static float4x4 unity_MatrixITMV = transpose(mul(unity_WorldToObject, unity_MatrixInvV));
// make them macros so that they can be redefined in UnityInstancing.cginc
#define UNITY_MATRIX_MVP    unity_MatrixMVP     // 模型空间变换到裁剪空间
#define UNITY_MATRIX_MV     unity_MatrixMV      // 模型空间变换到观察空间
#define UNITY_MATRIX_T_MV   unity_MatrixTMV     // 模型空间变换到观察空间的转置矩阵
#define UNITY_MATRIX_IT_MV  unity_MatrixITMV    // 模型空间变换到观察空间的转置矩阵的逆矩阵

// ----------------------------------------------------------------------------
//  Deprecated

// There used to be fixed function-like texture matrices, defined as UNITY_MATRIX_TEXTUREn. These are gone now; and are just defined to identity.
#define UNITY_MATRIX_TEXTURE0 float4x4(1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1)
#define UNITY_MATRIX_TEXTURE1 float4x4(1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1)
#define UNITY_MATRIX_TEXTURE2 float4x4(1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1)
#define UNITY_MATRIX_TEXTURE3 float4x4(1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1)

#endif
