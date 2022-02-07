// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

#ifndef UNITY_STANDARD_CORE_FORWARD_INCLUDED
#define UNITY_STANDARD_CORE_FORWARD_INCLUDED

#if defined(UNITY_NO_FULL_STANDARD_SHADER) // 如果没有定义全版本的标准着色器，就使用简单标准着色器
#   define UNITY_STANDARD_SIMPLE 1
#endif

#include "UnityStandardConfig.cginc" // 根据是否使用全版本的标准着色器进行跳转

#if UNITY_STANDARD_SIMPLE
    #include "UnityStandardCoreForwardSimple.cginc"
    VertexOutputBaseSimple vertBase (VertexInput v) { return vertForwardBaseSimple(v); }
    VertexOutputForwardAddSimple vertAdd (VertexInput v) { return vertForwardAddSimple(v); }
    half4 fragBase (VertexOutputBaseSimple i) : SV_Target { return fragForwardBaseSimpleInternal(i); }
    half4 fragAdd (VertexOutputForwardAddSimple i) : SV_Target { return fragForwardAddSimpleInternal(i); }
#else
    #include "UnityStandardCore.cginc"
    VertexOutputForwardBase vertBase (VertexInput v) { return vertForwardBase(v); }
    VertexOutputForwardAdd vertAdd (VertexInput v) { return vertForwardAdd(v); }
    half4 fragBase (VertexOutputForwardBase i) : SV_Target { return fragForwardBaseInternal(i); }
    half4 fragAdd (VertexOutputForwardAdd i) : SV_Target { return fragForwardAddInternal(i); }
#endif

#endif // UNITY_STANDARD_CORE_FORWARD_INCLUDED
