// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

Shader "Standard"
{
    Properties
    {
        _Color("Color", Color) = (1,1,1,1)  // 表面反照率颜色值
        _MainTex("Albedo", 2D) = "white" {} // 反照率贴图

        _Cutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0.5  // Cutoff值

        _Glossiness("Smoothness", Range(0.0, 1.0)) = 0.5    // 光滑度（当不使用金属度贴图时，可通过smoothness设置光滑度）
        _GlossMapScale("Smoothness Scale", Range(0.0, 1.0)) = 1.0   // 当使用金属度纹理时，可通过smoothness设置光滑度系数
        [Enum(Metallic Alpha,0,Albedo Alpha,1)] _SmoothnessTextureChannel ("Smoothness texture channel", Float) = 0 // 光滑度使用的通道

        [Gamma] _Metallic("Metallic", Range(0.0, 1.0)) = 0.0    // 当不使用金属度贴图时，可以直接设置Gamma空间的金属度值
        _MetallicGlossMap("Metallic", 2D) = "white" {}  // 使用金属度贴图

        [ToggleOff] _SpecularHighlights("Specular Highlights", Float) = 1.0 // 是否开启镜面高光反射
        [ToggleOff] _GlossyReflections("Glossy Reflections", Float) = 1.0   // 是否开启光泽度反射

        _BumpScale("Scale", Float) = 1.0    // 法线纹理系数
        [Normal] _BumpMap("Normal Map", 2D) = "bump" {} // 法线纹理贴图

        _Parallax ("Height Scale", Range (0.005, 0.08)) = 0.02  // 视差纹理高度系数
        _ParallaxMap ("Height Map", 2D) = "black" {}    // 视差纹理贴图

        _OcclusionStrength("Strength", Range(0.0, 1.0)) = 1.0 // AO遮蔽系数
        _OcclusionMap("Occlusion", 2D) = "white" {} // AO纹理贴图

        _EmissionColor("Color", Color) = (0,0,0)    // 自发光颜色
        _EmissionMap("Emission", 2D) = "white" {}   // 自发光纹理贴图

        _DetailMask("Detail Mask", 2D) = "white" {} // 细节纹理屏蔽纹理

        _DetailAlbedoMap("Detail Albedo x2", 2D) = "grey" {}    // 细节反照率纹理贴图
        _DetailNormalMapScale("Scale", Float) = 1.0 // 细节法线纹理系数
        [Normal] _DetailNormalMap("Normal Map", 2D) = "bump" {} // 细节法线纹理贴图

        [Enum(UV0,0,UV1,1)] _UVSec ("UV Set for secondary textures", Float) = 0 // 细节纹理的uv通道


        // Blending state 混合状态
        [HideInInspector] _Mode ("__mode", Float) = 0.0
        [HideInInspector] _SrcBlend ("__src", Float) = 1.0
        [HideInInspector] _DstBlend ("__dst", Float) = 0.0
        [HideInInspector] _ZWrite ("__zw", Float) = 1.0
    }

    CGINCLUDE
        #define UNITY_SETUP_BRDF_INPUT MetallicSetup    // 使用金属工作流，UnityStandardCore.cginc L228
    ENDCG
// 第一个SubShader ===================================================================================================================================
    SubShader
    {
        Tags { "RenderType"="Opaque" "PerformanceChecks"="False" }
        LOD 300


        // ------------------------------------------------------------------
        //  Base forward pass (directional light, emission, lightmaps, ...) 前向渲染路径，方向光、自发光、光照贴图等
        Pass
        {
            Name "FORWARD"
            Tags { "LightMode" = "ForwardBase" }

            Blend [_SrcBlend] [_DstBlend]
            ZWrite [_ZWrite]

            CGPROGRAM
            #pragma target 3.0  // 指定使用shader model 3.0

            // -------------------------------------

            #pragma shader_feature_local _NORMALMAP // 判定Normal Map是否启用
            #pragma shader_feature_local _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON    // 判定AlphaTest、AlphaBlend、Alpha预乘是否启用
            #pragma shader_feature _EMISSION // 判定自发光是否启用
            #pragma shader_feature_local _METALLICGLOSSMAP // 判定金属属性是否启用
            #pragma shader_feature_local _DETAIL_MULX2 // 判定细节纹理是否启用
            #pragma shader_feature_local _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A // 判定光滑度属性是否使用反照率纹理的alpha通道（否则是金属纹理的alpha通道）
            #pragma shader_feature_local _SPECULARHIGHLIGHTS_OFF // 判定镜面反射是否启用
            #pragma shader_feature_local _GLOSSYREFLECTIONS_OFF // 判定光泽反射是否启用
            #pragma shader_feature_local _PARALLAXMAP  // 判定视差纹理是否启用

            #pragma multi_compile_fwdbase // 编译前向渲染路径所依赖的所有着色器变种
            #pragma multi_compile_fog // 编译雾效所依赖的所有着色器变种（如线性雾、指数雾、指数平方）
            #pragma multi_compile_instancing // 编译实例化渲染技术所依赖的所有着色着色器变种
            // Uncomment the following line to enable dithering LOD crossfade. Note: there are more in the file to uncomment for other passes.
            //#pragma multi_compile _ LOD_FADE_CROSSFADE // 取消注释，则编译LOD交叉淡入淡出效果

            #pragma vertex vertBase // 指定顶点着色器
            #pragma fragment fragBase // 指定片元着色器
            #include "UnityStandardCoreForward.cginc"

            ENDCG
        }
        // ------------------------------------------------------------------
        //  Additive forward pass (one light per pass) 前向点光源渲染路径，点光、非主要方向光
        Pass
        {
            Name "FORWARD_DELTA"
            Tags { "LightMode" = "ForwardAdd" }
            Blend [_SrcBlend] One
            Fog { Color (0,0,0,0) } // in additive pass fog should be black
            ZWrite Off
            ZTest LEqual

            CGPROGRAM
            #pragma target 3.0

            // -------------------------------------


            #pragma shader_feature_local _NORMALMAP // 判定Normal Map是否启用
            #pragma shader_feature_local _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON   // 判定AlphaTest、AlphaBlend、Alpha预乘是否启用
            #pragma shader_feature_local _METALLICGLOSSMAP // 判定金属属性是否启用
            #pragma shader_feature_local _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A  // 判定光滑度属性是否使用反照率纹理的alpha通道（否则是金属纹理的alpha通道）
            #pragma shader_feature_local _SPECULARHIGHLIGHTS_OFF // 判定镜面反射是否启用
            #pragma shader_feature_local _DETAIL_MULX2 // 判定细节纹理是否启用
            #pragma shader_feature_local _PARALLAXMAP // 判定视差纹理是否启用

            #pragma multi_compile_fwdadd_fullshadows // 编译前向点光源渲染路径所依赖的所有阴影着色器变种
            #pragma multi_compile_fog // 编译雾效所依赖的所有着色器变种（如线性雾、指数雾、指数平方）
            // Uncomment the following line to enable dithering LOD crossfade. Note: there are more in the file to uncomment for other passes.
            //#pragma multi_compile _ LOD_FADE_CROSSFADE

            #pragma vertex vertAdd // 指定顶点着色器
            #pragma fragment fragAdd // 指定片元着色器
            #include "UnityStandardCoreForward.cginc"

            ENDCG
        }
        // ------------------------------------------------------------------
        //  Shadow rendering pass 阴影投射渲染路径，将物体的深度信息渲染到阴影贴图或者深度纹理中
        Pass {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }

            ZWrite On ZTest LEqual  // 需要打开ZWrite，写入条件是不大于缓冲区对应的z值

            CGPROGRAM
            #pragma target 3.0  // 需要使用Shader Model 3.0

            // -------------------------------------


            #pragma shader_feature_local _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON  // 判定AlphaTest、AlphaBlend、Alpha预乘是否启用
            #pragma shader_feature_local _METALLICGLOSSMAP // 判定金属属性是否启用
            #pragma shader_feature_local _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A  // 判定光滑度属性是否使用反照率纹理的alpha通道（否则是金属纹理的alpha通道）
            #pragma shader_feature_local _PARALLAXMAP// 判定视差纹理是否启用
            #pragma multi_compile_shadowcaster  // 在不平平台下实现阴影效果，点光源和其他类型光源需要不同的代码实现
            #pragma multi_compile_instancing // 编译实例化渲染技术所依赖的所有着色器变种
            // Uncomment the following line to enable dithering LOD crossfade. Note: there are more in the file to uncomment for other passes.
            //#pragma multi_compile _ LOD_FADE_CROSSFADE

            #pragma vertex vertShadowCaster // 指定顶点着色器
            #pragma fragment fragShadowCaster // 指定片元着色器

            #include "UnityStandardShadow.cginc"

            ENDCG
        }
        // ------------------------------------------------------------------
        //  Deferred pass 延迟渲染路径
        Pass
        {
            Name "DEFERRED"
            Tags { "LightMode" = "Deferred" }

            CGPROGRAM
            #pragma target 3.0
            #pragma exclude_renderers nomrt


            // -------------------------------------

            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
            #pragma shader_feature _EMISSION
            #pragma shader_feature_local _METALLICGLOSSMAP
            #pragma shader_feature_local _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            #pragma shader_feature_local _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature_local _DETAIL_MULX2
            #pragma shader_feature_local _PARALLAXMAP

            #pragma multi_compile_prepassfinal
            #pragma multi_compile_instancing
            // Uncomment the following line to enable dithering LOD crossfade. Note: there are more in the file to uncomment for other passes.
            //#pragma multi_compile _ LOD_FADE_CROSSFADE

            #pragma vertex vertDeferred
            #pragma fragment fragDeferred

            #include "UnityStandardCore.cginc"

            ENDCG
        }

        // ------------------------------------------------------------------
        // Extracts information for lightmapping, GI (emission, albedo, ...)
        // This pass it not used during regular rendering. 元渲染路径，在生成光照贴图时使用，其他情况不使用
        Pass
        {
            Name "META"
            Tags { "LightMode"="Meta" }

            Cull Off

            CGPROGRAM
            #pragma vertex vert_meta
            #pragma fragment frag_meta

            #pragma shader_feature _EMISSION
            #pragma shader_feature_local _METALLICGLOSSMAP
            #pragma shader_feature_local _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            #pragma shader_feature_local _DETAIL_MULX2
            #pragma shader_feature EDITOR_VISUALIZATION

            #include "UnityStandardMeta.cginc"
            ENDCG
        }
    }
// 第二个SubShader ===================================================================================================================================
    SubShader
    {
        Tags { "RenderType"="Opaque" "PerformanceChecks"="False" }
        LOD 150

        // ------------------------------------------------------------------
        //  Base forward pass (directional light, emission, lightmaps, ...)
        Pass
        {
            Name "FORWARD"
            Tags { "LightMode" = "ForwardBase" }

            Blend [_SrcBlend] [_DstBlend]
            ZWrite [_ZWrite]

            CGPROGRAM
            #pragma target 2.0

            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
            #pragma shader_feature _EMISSION
            #pragma shader_feature_local _METALLICGLOSSMAP
            #pragma shader_feature_local _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            #pragma shader_feature_local _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature_local _GLOSSYREFLECTIONS_OFF
            // SM2.0: NOT SUPPORTED shader_feature_local _DETAIL_MULX2
            // SM2.0: NOT SUPPORTED shader_feature_local _PARALLAXMAP

            #pragma skip_variants SHADOWS_SOFT DIRLIGHTMAP_COMBINED

            #pragma multi_compile_fwdbase
            #pragma multi_compile_fog

            #pragma vertex vertBase
            #pragma fragment fragBase
            #include "UnityStandardCoreForward.cginc"

            ENDCG
        }
        // ------------------------------------------------------------------
        //  Additive forward pass (one light per pass)
        Pass
        {
            Name "FORWARD_DELTA"
            Tags { "LightMode" = "ForwardAdd" }
            Blend [_SrcBlend] One
            Fog { Color (0,0,0,0) } // in additive pass fog should be black
            ZWrite Off
            ZTest LEqual

            CGPROGRAM
            #pragma target 2.0

            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
            #pragma shader_feature_local _METALLICGLOSSMAP
            #pragma shader_feature_local _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            #pragma shader_feature_local _SPECULARHIGHLIGHTS_OFF
            #pragma shader_feature_local _DETAIL_MULX2
            // SM2.0: NOT SUPPORTED shader_feature_local _PARALLAXMAP
            #pragma skip_variants SHADOWS_SOFT

            #pragma multi_compile_fwdadd_fullshadows
            #pragma multi_compile_fog

            #pragma vertex vertAdd
            #pragma fragment fragAdd
            #include "UnityStandardCoreForward.cginc"

            ENDCG
        }
        // ------------------------------------------------------------------
        //  Shadow rendering pass
        Pass {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }

            ZWrite On ZTest LEqual

            CGPROGRAM
            #pragma target 2.0

            #pragma shader_feature_local _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
            #pragma shader_feature_local _METALLICGLOSSMAP
            #pragma shader_feature_local _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            #pragma skip_variants SHADOWS_SOFT
            #pragma multi_compile_shadowcaster

            #pragma vertex vertShadowCaster
            #pragma fragment fragShadowCaster

            #include "UnityStandardShadow.cginc"

            ENDCG
        }

        // ------------------------------------------------------------------
        // Extracts information for lightmapping, GI (emission, albedo, ...)
        // This pass it not used during regular rendering.
        Pass
        {
            Name "META"
            Tags { "LightMode"="Meta" }

            Cull Off

            CGPROGRAM
            #pragma vertex vert_meta
            #pragma fragment frag_meta

            #pragma shader_feature _EMISSION
            #pragma shader_feature_local _METALLICGLOSSMAP
            #pragma shader_feature_local _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
            #pragma shader_feature_local _DETAIL_MULX2
            #pragma shader_feature EDITOR_VISUALIZATION

            #include "UnityStandardMeta.cginc"
            ENDCG
        }
    }


    FallBack "VertexLit"
    CustomEditor "StandardShaderGUI"
}
