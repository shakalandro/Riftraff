#version 150
in vec4 texPosition;
in vec4 vertPosition;
out vec4 fragColor;
uniform sampler2DRect tex;
uniform vec2 lensOffset;
uniform vec2 screenSize;
uniform vec2 screenCenter;
uniform vec2 scale;
uniform vec2 scaleIn;
uniform vec2 transIn;
uniform vec4 HmdWarpParam;
vec2 HmdWarp(vec2 in01)
{
  // Explanation:
  // 1) in01 is in the texture's coordinate range
  // 2) translate the coordinate to be centered at the origin
  // 3) apply the oculus lens offset
  // 4) scale down to the unit range [-1,1]
  // 5) apply the barrel distortion
  // 6) apply the inverse of 2 and 4
  // NOTE: we do not invert the lense offset because our images are not configured with
  //    the offset already, ie without distortion, they do not appear 3D because
  //    of the missing offset
  vec2 theta = (in01 - transIn - lensOffset) * scaleIn;
  float rSq = theta.x * theta.x + theta.y * theta.y;
  vec2 ret = theta * (
                      HmdWarpParam.x +
                      HmdWarpParam.y * rSq +
                      HmdWarpParam.z * rSq * rSq +
                      HmdWarpParam.w * rSq * rSq * rSq
                      );
  return ret / scaleIn * scale + transIn;
}
void main(void)
{
  vec2 tc = HmdWarp(texPosition.xy);

  // Clamp the pixels that go outside the eye view
  vec2 min = screenCenter - screenSize / 2.0;
  vec2 max = screenCenter + screenSize / 2.0;
  if (any(notEqual(clamp(tc, min, max) - tc, vec2(0.0, 0.0))))
  {
    // Render a black pixel for anything outside of this eye's viewport
    fragColor = vec4(0.0, 0.0, 0.0, 1.0);
  } else {
    // Test banding for calculating the proper
    // center and scale parameters
    // When running without warping, the bands
    // from the two eyes should align
    // When running with warping, the bands
    // should aling and appear straight
    float bandWidth = 0.1;
    bool debug = false;
    if ( debug &&
        (((abs(tc.x - screenCenter.x) > (screenSize.x / 2) * (1.0 - bandWidth)) &&
         (abs(tc.x - screenCenter.x) < screenSize.x / 2)) ||
        ((abs(tc.y - screenCenter.y) > (screenSize.y / 2) * (1.0 - bandWidth)) &&
         (abs(tc.y - screenCenter.y) < screenSize.y / 2))))
    {
      fragColor = vec4(1.0, 0.0, 0.0, 1.0);
    } else {
      fragColor = texelFetch(tex, ivec2(tc.x, tc.y));
    }
  }
}