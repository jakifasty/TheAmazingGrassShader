Shader "Roystan/Grass"
{
    Properties
    {
		[Header(Shading)]
        _TopColor("Top Color", Color) = (1,1,1,1)
		_BottomColor("Bottom Color", Color) = (1,1,1,1)
		_TranslucentGain("Translucent Gain", Range(0,1)) = 0.5
		_BendRotationRandom("Bend Rotation Random", Range(0, 1)) = 0.2 //adding new property for random forward bend

		_BladeWidth("Blade Width", Float) = 0.05 //adding new properties to control width and height
		_BladeWidthRandom("Blade Width Random", Float) = 0.02
		_BladeHeight("Blade Height", Float) = 0.5
		_BladeHeightRandom("Blade Height Random", Float) = 0.3

		//wind properties
		_WindDistortionMap("Wind Distortion Map", 2D) = "white" {}
		_WindFrequency("Wind Frequency", Vector) = (0.05, 0.05, 0, 0)
		_WindStrength("Wind Strength", Float) = 1

		//control the tessellation amount
		_TessellationUniform("Tessellation Uniform", Range(2, 128)) = 1

    }

	CGINCLUDE
	#include "UnityCG.cginc"
	#include "Autolight.cginc"
	#include "Shaders/CustomTessellation.cginc"

	// Simple noise function, sourced from http://answers.unity.com/answers/624136/view.html
	// Extended discussion on this function can be found at the following link:
	// https://forum.unity.com/threads/am-i-over-complicating-this-random-function.454887/#post-2949326
	// Returns a number in the 0...1 range.
	float rand(float3 co)
	{
		return frac(sin(dot(co.xyz, float3(12.9898, 78.233, 53.539))) * 43758.5453);
	}

	struct geometryOutput //this creates a geometry shader 
	{
		float4 pos : SV_POSITION;
		float2 uv: TEXTCOORD0; //declare uv coordinates
	};

	float _BendRotationRandom;

	float _BladeHeight;
	float _BladeHeightRandom;
	float _BladeWidth;
	float _BladeWidthRandom;

	sampler2D _WindDistortionMap; //used for the wind prop 
	float4 _WindDistortionMap_ST;
	float _WindStrength;

	float2 _WindFrequency; //how often the wind will blow

	// Construct a rotation matrix that rotates around the provided axis, sourced from:
	// https://gist.github.com/keijiro/ee439d5e7388f3aafc5296005c8c3f33
	float3x3 AngleAxis3x3(float angle, float3 axis)
	{
		float c, s;
		sincos(angle, s, c);

		float t = 1 - c;
		float x = axis.x;
		float y = axis.y;
		float z = axis.z;

		return float3x3(
			t * x * x + c, t * x * y - s * z, t * x * z + s * y,
			t * x * y + s * z, t * y * y + c, t * y * z - s * x,
			t * x * z - s * y, t * y * z + s * x, t * z * z + c
			);
	}

	geometryOutput VertexOutput(float3 pos, float uv)
	{
		geometryOutput o;
		o.pos = UnityObjectToClipPos(pos);
		o.uv = uv; //assign uv vectors to the geometryOutput object
		return o;
	}


	[maxvertexcount(3)] //This tells the GPU that we will emit (but are not required to) at most 3 vertices
	//this takes in a vertex as input and output a single triangle to represent to represent a blade of grass
	void geo(triangle vertexOutput IN[3]: SV_POSITION, inout TriangleStream<geometryOutput> triStream)
	{ //this a geometry shader

		float3 pos = IN[0].vertex;

		float3 vNormal = IN[0].normal;
		float4 vTangent = IN[0].tangent;
		float3 vBinormal = cross(vNormal, vTangent) * vTangent.w; //third vector perpendicular to its two input vectors
		geometryOutput o;

		float3x3 tangentToLocal = float3x3(
			vTangent.x, vBinormal.x, vNormal.x,
			vTangent.y, vBinormal.y, vNormal.y,
			vTangent.z, vBinormal.z, vNormal.z
		);

		float2 uv = pos.xz * _WindDistortionMap_ST.xy + _WindDistortionMap_ST.zw + _WindFrequency * _Time.y; //calculate uv coordinates as a fucntion of wind parameters
		float2 windSample = (tex2Dlod(_WindDistortionMap, float4(uv, 0, 0)).xy * 2 - 1) * _WindStrength;
		float3 wind = normalize(float3(windSample.x, windSample.y, 0));
		float3x3 windRotation = AngleAxis3x3(UNITY_PI * windSample, wind);

		//create a new matrix to rotate the grass along its X axis, and a property to control this rotation
		float3x3 bendRotationMatrix = AngleAxis3x3(rand(pos.zzx) * _BendRotationRandom * UNITY_PI * 0.5, float3(-1, 0, 0));

		float3x3 facingRotationMatrix = AngleAxis3x3(rand(pos) * UNITY_TWO_PI, float3(0, 0, 1)); //declaring rotation matrix to make look the grass more natural
		//float3x3 transformationMatrix = mul(mul(tangentToLocal, facingRotationMatrix), bendRotationMatrix); // apply this matrix through rotation
		float3x3 transformationMatrix = mul(mul(mul(tangentToLocal, windRotation), facingRotationMatrix), bendRotationMatrix); // apply this matrix through rotation

		float height = (rand(pos.zyx) * 2 - 1) * _BladeHeightRandom + _BladeHeight;
		float width = (rand(pos.xzy) * 2 - 1) * _BladeWidthRandom + _BladeWidth;

		//this emmits a triangle every time it is called
		/*o.pos = UnityObjectToClipPos(pos + float4(0.5, 0, 0, 1));
		triStream.Append(o);

		o.pos = UnityObjectToClipPos(pos + float4(-0.5, 0, 0, 1));
		triStream.Append(o);

		o.pos = UnityObjectToClipPos(pos + float4(0, 1, 0, 1));
		triStream.Append(o);*/

		//triStream.Append(VertexOutput(pos + float3(0.5, 0, 0)));
		//triStream.Append(VertexOutput(pos + float3(-0.5, 0, 0)));
		//triStream.Append(VertexOutput(pos + float3(0, 1, 0)));

		/*triStream.Append(VertexOutput(pos + mul(tangentToLocal, float3(0.5, 0, 0)), float2(0, 0)));
		triStream.Append(VertexOutput(pos + mul(tangentToLocal, float3(-0.5, 0, 0)), float2(1, 0))); 
		triStream.Append(VertexOutput(pos + mul(tangentToLocal, float3(0, 0, 1)), float2(0.5, 1)));*/

		//triStream.Append(VertexOutput(pos + mul(transformationMatrix, float3(0.5, 0, 0)), float2(0, 0)));  //added as a 3rd parameter the uv Vector2
		//triStream.Append(VertexOutput(pos + mul(transformationMatrix, float3(-0.5, 0, 0)), float2(1, 0))); //added as a 3rd parameter the uv Vector2
		//triStream.Append(VertexOutput(pos + mul(transformationMatrix, float3(0, 0, 1)), float2(0.5, 1))); //modifyed by float3(0, 1, 0)

		triStream.Append(VertexOutput(pos + mul(transformationMatrix, float3(width, 0, 0)), float2(0, 0)));
		triStream.Append(VertexOutput(pos + mul(transformationMatrix, float3(-width, 0, 0)), float2(1, 0)));
		triStream.Append(VertexOutput(pos + mul(transformationMatrix, float3(0, 0, height)), float2(0.5, 1)));
	}

	/*float4 vert(float4 vertex : POSITION) : SV_POSITION
	{
		//return UnityObjectToClipPos(vertex);
		return vertex; //updating the return call in the vertex shader
	}*/

	ENDCG

    SubShader
    {
		Cull Off

        Pass
        {
			Tags
			{
				"RenderType" = "Opaque"
				"LightMode" = "ForwardBase"
			}

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
			#pragma target 4.6
			#pragma hull hull
			#pragma domain domain

			#pragma geometry geo //geometry shader (pragma directives in HLSL), to make sure it uses the geometry shader
            
			#include "Lighting.cginc"

			float4 _TopColor;
			float4 _BottomColor;
			float _TranslucentGain;

			//now sample our top and bottom colors in the fragment shader using the UV, and interpolate
			//between them using lerp. We'll also need to modify the fragment shader's parameters to take
			//geometryOutput as input, rather just only the float4 position.
			float4 frag (geometryOutput i, fixed facing : VFACE) : SV_Target
            {	
				return lerp(_BottomColor, _TopColor, i.uv.y);
            }
            ENDCG
        }
    }
}