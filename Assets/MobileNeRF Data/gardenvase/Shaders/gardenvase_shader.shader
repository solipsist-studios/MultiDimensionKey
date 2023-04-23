Shader "MobileNeRF/ViewDependenceNetworkShader/gardenvase" {
    Properties {
        tDiffuse0x ("Diffuse Texture 0", 2D) = "white" {}
        tDiffuse1x ("Diffuse Texture 1", 2D) = "white" {}
        weightsZero ("Weights Zero", 2D) = "white" {}
        weightsOne ("Weights One", 2D) = "white" {}
        weightsTwo ("Weights Two", 2D) = "white" {}
    }

    CGINCLUDE
    #include "UnityCG.cginc"

    struct appdata {
        float4 vertex : POSITION;
        float2 uv : TEXCOORD0;
        UNITY_VERTEX_INPUT_INSTANCE_ID
    };

    struct v2f {
        float2 uv : TEXCOORD0;
        float4 vertex : SV_POSITION;
        float3 rayDirection : TEXCOORD1;
        UNITY_VERTEX_OUTPUT_STEREO
    };

    v2f vert(appdata v) {
        v2f o;

        UNITY_SETUP_INSTANCE_ID(v);
        UNITY_INITIALIZE_OUTPUT(v2f, o);
        UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

        o.vertex = UnityObjectToClipPos(v.vertex);
        o.uv = v.uv;
        o.rayDirection = -WorldSpaceViewDir(v.vertex);
        o.rayDirection.xz = -o.rayDirection.xz;o.rayDirection.xyz = o.rayDirection.xzy;

        return o;
    }

    sampler2D tDiffuse0x;
    sampler2D tDiffuse1x;
    sampler2D tDiffuse2x;

    UNITY_DECLARE_TEX2D(weightsZero);
    UNITY_DECLARE_TEX2D(weightsOne);
    UNITY_DECLARE_TEX2D(weightsTwo);

    half3 evaluateNetwork(fixed4 f0, fixed4 f1, fixed4 viewdir) {
        half intermediate_one[16] = { 0.2135161, -0.2953411, -0.0835989, 0.1848784, -0.1620431, 0.0993345, -0.0484438, 0.0812181, 0.6863000, -0.0887935, 0.0283477, 0.1376160, 0.0466352, 0.0503299, -0.1477253, 0.0118059 };
        int i = 0;
        int j = 0;

        for (j = 0; j < 11; ++j) {
            half input_value = 0.0;
            if (j < 4) {
            input_value =
                (j == 0) ? f0.r : (
                (j == 1) ? f0.g : (
                (j == 2) ? f0.b : f0.a));
            } else if (j < 8) {
            input_value =
                (j == 4) ? f1.r : (
                (j == 5) ? f1.g : (
                (j == 6) ? f1.b : f1.a));
            } else {
            input_value =
                (j == 8) ? viewdir.r : (
                (j == 9) ? viewdir.g : viewdir.b);
            }
            for (i = 0; i < 16; ++i) {
            intermediate_one[i] += input_value * weightsZero.Load(int3(j, i, 0)).x;
            }
        }

        half intermediate_two[16] = { 0.0084802, -0.1296202, 0.1942869, 0.0164647, 0.1926397, -0.0295624, -0.1146625, 0.1082923, 0.1511832, 0.0263304, -0.0156775, 0.0982237, -0.0791039, 0.1312845, 0.1543348, -0.2194370 };

        for (j = 0; j < 16; ++j) {
            if (intermediate_one[j] <= 0.0) {
                continue;
            }
            for (i = 0; i < 16; ++i) {
                intermediate_two[i] += intermediate_one[j] * weightsOne.Load(int3(j, i, 0)).x;
            }
        }

        half result[3] = { -0.3003545, -0.0100401, -0.0409711 };

        for (j = 0; j < 16; ++j) {
            if (intermediate_two[j] <= 0.0) {
                continue;
            }
            for (i = 0; i < 3; ++i) {
                result[i] += intermediate_two[j] * weightsTwo.Load(int3(j, i, 0)).x;
            }
        }
        for (i = 0; i < 3; ++i) {
            result[i] = 1.0 / (1.0 + exp(-result[i]));
        }
        return half3(result[0]*viewdir.a+(1.0-viewdir.a),
                    result[1]*viewdir.a+(1.0-viewdir.a),
                    result[2]*viewdir.a+(1.0-viewdir.a));
    }
    ENDCG

    SubShader {
        Cull Off
        ZTest LEqual

        Pass {
            CGPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            fixed4 frag(v2f i) : SV_Target {
                fixed4 diffuse0 = tex2D( tDiffuse0x, i.uv );
                if (diffuse0.r == 0.0) discard;
                fixed4 diffuse1 = tex2D( tDiffuse1x, i.uv );
                fixed4 rayDir = fixed4(normalize(i.rayDirection), 1.0);

                //deal with iphone
                diffuse0.a = diffuse0.a*2.0-1.0;
                diffuse1.a = diffuse1.a*2.0-1.0;
                rayDir.a = rayDir.a*2.0-1.0;

                fixed4 fragColor;
                fragColor.rgb = evaluateNetwork(diffuse0,diffuse1,rayDir);
                fragColor.a = 1.0;

                #if(!UNITY_COLORSPACE_GAMMA)
                    fragColor.rgb = GammaToLinearSpace(fragColor.rgb);
                #endif

                return fragColor;
            }
            ENDCG
        }

        // ------------------------------------------------------------------
        //  Shadow rendering pass
        Pass {
            Tags {"LightMode" = "ShadowCaster"}

            CGPROGRAM

            #pragma vertex vert
            #pragma fragment fragShadowCaster
            #pragma multi_compile_shadowcaster

            fixed4 fragShadowCaster(v2f i) : SV_Target{
                fixed4 diffuse0 = tex2D(tDiffuse0x, i.uv);
                if (diffuse0.r == 0.0) discard;
                return 0;
            }
            ENDCG
        }
    }
}