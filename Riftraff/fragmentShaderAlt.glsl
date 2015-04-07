uniform sampler2D texture;
uniform vec2 LensCenter;
uniform vec2 ScreenCenter;
uniform vec2 Scale;
uniform vec2 ScaleIn;
uniform vec4 HmdWarpParam;
// Scales input texture coordinates for distortion.
vec2 HmdWarp(vec2 texIn)
{
  // Scales to [-1, 1]
  vec2 theta = (texIn - LensCenter) * ScaleIn;
  float rSq = theta.x * theta.x + theta.y * theta.y;
  vec2 theta1 = theta * (
                         HmdWarpParam.x +
                         HmdWarpParam.y * rSq +
                         HmdWarpParam.z * rSq * rSq +
                         HmdWarpParam.w * rSq * rSq * rSq
                         );
  return LensCenter + Scale * theta1;
}
void main()
{
  vec2 tc = HmdWarp(gl_TexCoord[0].xy);
  if (any(notEqual(clamp(tc,
                         ScreenCenter-vec2(0.25,0.5),
                         ScreenCenter+vec2(0.25, 0.5)
                         ) - tc,
                   vec2(0.0, 0.0)
                   )
          )
      )
  {
    // Render green pixel
    gl_FragColor = vec4(0.0, 1.0, 0.0, 1.0);
  }
  else
  {
    // Grab the texture pixel from the distorted coords
    gl_FragColor = texture2D(texture, tc);
  }
}