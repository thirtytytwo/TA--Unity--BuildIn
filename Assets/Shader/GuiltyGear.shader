Shader "Thirtytwo/GuiltyGear"
{
    Properties
    {
        [Space]
        _MainTex                      ("主贴图", 2D)                = "white"{}
        _Diffuse                      ("漫反射颜色", Color)         = (1,1,1,1)
        [Space]              
        _ShadowMap                    ("阴影贴图", 2D)              = "white"{}
        _ShadowIntensity              ("阴影强度", Range(0,1))      = 0.7
        [Space]              
        _DetailMap                    ("磨损线条贴图", 2D)           = "white"{}
        _DetailIntensity              ("磨损强度", Range(0,1))      = 1 
        [Space]              
        _LightMap                     ("光照贴图", 2D)              = "white"{}
        _RampOffset                   ("Ramp偏移量", Range(0,1))    = 0
        _LightTreshold                ("光照边缘范围", Range(0,1))   = 0.5
        [Space]              
        _DecalTex                     ("贴花", 2D) = "white"{}
        [Space]              
        _RimWidth                     ("边缘光宽度", Range(0,1))     = 0.5
        _RimIntensity                 ("边缘光强度", Range(0,1))     = 0.7
        [Space]              
        _SpecularPower                ("高光粗糙度", Range(0,50))    = 15
        _SpecularIntensity            ("高光强度",Range(0,5))        = 1
        [Space]  
        _MetallicStepSpecularWidth    ("金属的高光宽度", Range(0,1))  = 0.5
        _MetallicStepSpecularIntensity("金属的高光强度", Range(0,1))  = 0.8
        [Space]
        _LayerMaskStep                ("身体区域切分(用来处理部位分割问题，例如膝盖处高光)",Range(0,255)) = 35
        _BodySpecularWidth            ("身体的高光宽度", Range(0,1))  = 0.5
        _BodySpecularIntensity        ("身体的高光强度", Range(0,1))  = 0.8
        [Space]
        [Toggle]_FACESHADOWTEX        ("启用脸部阴影图", Float)       = 0
        _HeadSpecularWidth            ("头部的高光宽度", Range(0,1))  = 0.5
        _HeadSpecularIntensity        ("头部的高光强度", Range(0,1))  = 0.8
        [Space]
        _OutlineWidth                 ("描边大小", Range(0,1))       = 0.1
        _OutlineColor                 ("描边颜色", Color)             = (1,1,1,1)
    }
    SubShader
    {
    
        LOD 100
        
        //Base
        Pass
        {
            Tags { "RenderType"="Opaque" "LightMode" = "ForwardBase" }
            ZWrite On
            Cull Back
            
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma shader_feature _FACESHADOWTEX_ON
            #pragma multi_compile_fwdbase
            #include "Lighting.cginc"
            #include "AutoLight.cginc"
            
            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float4 vertexColor : COLOR;
                float2 uv : TEXCOORD0;
                float2 uv2 : TEXCOORD1;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float3 worldNormal : NORMAL;
                float4 uv : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
                float4 vertexColor : TEXCOORD2;
                float3 tangent : TEXCOORD3;
                LIGHTING_COORDS(4, 5)
            };
            //基础计算数据
            struct BaseCompute
            {
                fixed3 tangent  ;
                fixed3 normalDir;
                fixed3 lightDir ;
                fixed3 viewDir  ;
                fixed3 halfDir  ;
                fixed  NdotL    ;
                fixed  NdotL01  ;
                fixed  NdotV    ;
                fixed  NdotH    ;
            };
            //贴图集合
            struct TextureCollection
            {
                fixed4 mainTex;
                fixed4 lightMap;
                fixed4 detailTex;
                fixed4 shadowMap;
                fixed4 decalTex;
                float  specularLayerMask;   
                float  rampOffsetMask;
                float  specularIntensityMask;
                float  innerLineMask;
                float  shadowAOMask;
                float  modelPart;
                float  outlineIntensity;
            };
            
            sampler2D _MainTex;
            fixed4 _MainTex_ST;
            sampler2D _LightMap;
            float4 _Diffuse;
            float _SpecularPower;
            float _SpecularIntensity;
            float _MetallicStepSpecularWidth;
            float _MetallicStepSpecularIntensity;
            float _LayerMaskStep;
            float _BodySpecularWidth;
            float _BodySpecularIntensity;
            float _HeadSpecularWidth;
            float _HeadSpecularIntensity;
            float _LightTreshold;
            float _RampOffset;
            sampler2D _DetailMap;
            float _DetailIntensity;
            sampler2D _DecalTex;
            sampler2D _ShadowMap;
            float _ShadowIntensity;
            float _RimWidth;
            float _RimIntensity;
            float _Min;
            float _Max;
            float _Test01;
            TextureCollection texCol;
            BaseCompute baseData;
            
            
            //------------------------------------基础数据---------------------------------------
            void ComputeBaseData(v2f i)
            {
                baseData.tangent   = normalize(i.tangent);
                baseData.normalDir = normalize(i.worldNormal);//法向量
                baseData.lightDir  = normalize(UnityWorldSpaceLightDir(i.worldPos)); //入射光方向
                baseData.viewDir   = normalize(UnityWorldSpaceViewDir(i.worldPos));//视线方向
                baseData.halfDir   = normalize(baseData.viewDir + baseData.lightDir);//中间量
                baseData.NdotL     = dot(baseData.normalDir, baseData.lightDir);
                baseData.NdotL01   = baseData.NdotL * 0.5 + 0.5;
                baseData.NdotV     = dot(baseData.normalDir, baseData.viewDir);
                baseData.NdotH     = dot(baseData.normalDir, baseData.halfDir);
            }
            
            //------------------------------------贴图---------------------------------------
            void SampleBaseTexture(v2f i)
            {
                texCol.mainTex               = tex2D(_MainTex, i.uv);
                texCol.lightMap              = tex2D(_LightMap, i.uv);
                texCol.detailTex             = tex2D(_DetailMap, i.uv.zw);
                texCol.shadowMap             = tex2D(_ShadowMap, i.uv);
                texCol.decalTex              = tex2D(_DecalTex, i.uv);
                texCol.specularLayerMask     = texCol.lightMap.r;     //高光材质类型（通用、金属、皮革）
                texCol.rampOffsetMask        = texCol.lightMap.g;     //Ramp偏移值
                texCol.specularIntensityMask = texCol.lightMap.b;     //高光强度类型Mask（无高光、裁边高光、Blinn-Phong高光）
                texCol.innerLineMask         = texCol.lightMap.a;     //内勾线Mask
                texCol.shadowAOMask          = i.vertexColor.r;//AO常暗部分
                texCol.modelPart             = i.vertexColor.g;//用来区分身体的部位，比如脸部=88
                texCol.outlineIntensity      = i.vertexColor.b;//描边粗细
                                             // = i.vertexColor.a;//没用到的通道
            }
            
            //------------------------------------漫反射---------------------------------------
            fixed3 Diffuse(float threshold)
            {
                //裁边漫反射
                texCol.mainTex *= texCol.innerLineMask ; // 磨损线条
                texCol.mainTex = lerp(texCol.mainTex, texCol.mainTex * texCol.detailTex, _DetailIntensity);//控制磨损线条强度
                float3 diffuse = lerp(lerp(texCol.shadowMap, texCol.mainTex,(1 - _ShadowIntensity)), texCol.mainTex, threshold) * _LightColor0.rgb;
                return diffuse * _LightColor0.rgb;
            }
            
            //------------------------------------Rim---------------------------------------
            fixed3 Rim(float threshold)
            {
                float3 rim = step(1 - _RimWidth,(1 - baseData.NdotV)) * _RimIntensity * texCol.mainTex;
                rim = lerp(0,rim, threshold);
                rim = max(0, rim);
                rim *= _LightColor0.rgb;
                return rim ;
            }
            
            //------------------------------------高光---------------------------------------
            fixed3 Specular()
            {
                float3 specular = 0;
                specular = pow(saturate(baseData.NdotH), _SpecularPower) * _SpecularIntensity * texCol.specularIntensityMask * texCol.mainTex ;
                specular = max(0, specular);
                // LayerMask
                // [0,10] 普通 无边缘光  
                // (10,145]皮革 皮肤 有边缘光
                // (145,200] 头发 有边缘光
                // (200,255] 金属 裁剪高光 无边缘光
                float linearMask = pow(texCol.specularLayerMask, 1 / 2.2);
                float layerMask = linearMask * 255;

                //皮革边缘处 大腿皮肤 裁边高光
                if(layerMask >= 10 && layerMask < _LayerMaskStep)
                {
                    float specularIntensity = pow(texCol.specularIntensityMask, 1 / 2.2) * 255;
                    float stepSpecularMask = float(specularIntensity > 0 && specularIntensity <= 140); //step(0,SpecularIntensity) * step(140,SpecularIntensity)
                    float3 bodySpecular = saturate(step(1 - baseData.NdotV, _BodySpecularWidth)) * _BodySpecularIntensity * texCol.mainTex;
                    specular = lerp(specular, bodySpecular, stepSpecularMask);
                }
                //头发 有边缘光
                if(layerMask > 145 && layerMask <= 200)
                {
                    float specularIntensity = pow(texCol.specularIntensityMask, 1 / 2.2) * 255;
                    float stepSpecularMask = float(specularIntensity > 140 && specularIntensity <= 255); // step(0,SpecularIntensity) * step(128,SpecularIntensity)
                    float3 hairSpecular =saturate(step(1 - _HeadSpecularWidth, baseData.NdotV)) * _HeadSpecularIntensity * texCol.mainTex * stepSpecularMask;
                    specular = lerp(specular, hairSpecular, stepSpecularMask);
                }

                //金属 裁剪高光 无边缘光
                if(layerMask > 200 )
                {
                    float3 metallicStepSpecular = step(baseData.NdotL01, _MetallicStepSpecularWidth) * _MetallicStepSpecularIntensity * texCol.mainTex;
                    specular += metallicStepSpecular;
                }
                specular *= _LightColor0.rgb;
                return specular;
            }
            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                o.tangent = UnityObjectToWorldDir(v.tangent);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.uv.xy = TRANSFORM_TEX(v.uv, _MainTex);
                o.uv.zw = v.uv2;
                o.vertexColor = v.vertexColor;
                TRANSFER_VERTEX_TO_FRAGMENT(o);
                return o;
            }
            
            fixed4 frag (v2f i) : SV_Target
            {
                ComputeBaseData(i);
                SampleBaseTexture(i);
            
                //裁边漫反射
                float threshold = saturate(step(_LightTreshold, (baseData.NdotL01  + _RampOffset + texCol.rampOffsetMask) * texCol.shadowAOMask));
                float3 diffuse = Diffuse(threshold);
                float3 ambient = UNITY_LIGHTMODEL_AMBIENT.rgb * texCol.mainTex;
                
                #ifdef _FACESHADOWTEX_ON
                    if(texCol.modelPart >= 0.22 && texCol.modelPart < 0.26)
                    {
                        diffuse = Diffuse(threshold);
                        return fixed4(diffuse + ambient,1.0);
                    } 
                #endif
                
                float3 rim = Rim(threshold);
                float3 specular = Specular();
            
                fixed3 color = diffuse + rim + specular + ambient ;
                return fixed4(color,1.0);
            }
            ENDCG
        }
        
        //Outline
        Pass
        {
            Name "Outline"
            Cull Front
            
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            #include "UnityCG.cginc"
            
            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float4 vertexColor : Color;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
            };
            
            float _OutlineWidth;
            float4 _OutlineColor;
            float4 _LightColor0;
            
            v2f vert(appdata v)
            {
                v2f o;
                UNITY_INITIALIZE_OUTPUT(v2f, o);
                float4 pos = UnityObjectToClipPos(v.vertex);
                float3 viewNormal = mul((float3x3)UNITY_MATRIX_IT_MV, v.tangent.xyz);
                float3 ndcNormal = normalize(TransformViewToProjection(viewNormal.xyz)) * pos.w;//将法线变换到NDC空间，保证描边没有近大远小的情况
                float4 nearUpperRight = mul(unity_CameraInvProjection, float4(1,1, UNITY_NEAR_CLIP_VALUE, _ProjectionParams.y));//将近裁剪面右上角位置的顶点变换到观察空间 https://www.cnblogs.com/wbaoqing/p/5433193.html
                float aspect = abs(nearUpperRight.y / nearUpperRight.x);//求得屏幕宽高比
                ndcNormal.x *= aspect;
                pos.xy += _OutlineWidth * 0.01 * ndcNormal;
                o.pos = pos;
                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                return _OutlineColor;
            }
            
            ENDCG
        }
    }
    FallBack "Diffuse"
}
