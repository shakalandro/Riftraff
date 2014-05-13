uniform Texture2D Texture : register(t0);
uniform SamplerState Linear : register(s0);
uniform float2 LensCenter;
uniform float2 ScreenCenter;
uniform float2 Scale;
uniform float2 ScaleIn;
uniform float4 HmdWarpParam;
// Scales input texture coordinates for distortion.
float2 HmdWarp(float2 in01)
{
  // Scales to [-1, 1]
  float2 theta = (in01 - LensCenter) * ScaleIn;
  float rSq = theta.x * theta.x + theta.y * theta.y;
  float2 rvector= theta * (
                           HmdWarpParam.x +
                           HmdWarpParam.y * rSq +
                           HmdWarpParam.z * rSq * rSq +
                           HmdWarpParam.w * rSq * rSq * rSq
                           );
  return LensCenter + Scale * rvector;
}
float4 main(in float4 oPosition : SV_Position,
            in float4 oColor : COLOR,
            in float2 oTexCoord : TEXCOORD0
            ) : SV_Target
{
  float2 tc = HmdWarp(oTexCoord);
  if (any(clamp(tc,
                ScreenCenter-float2(0.25,0.5),
                ScreenCenter+float2(0.25, 0.5)
                ) - tc
          )
      )

    // Render black pixel
    return float4(0.0, 0.0, 1.0, 1.0);

  // Grab the texture pixel from the distorted coords
  return Texture.Sample(Linear, tc);
}