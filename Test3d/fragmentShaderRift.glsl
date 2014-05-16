#version 150
in vec4 texPosition;
in vec4 vertPosition;
out vec4 fragColor;
uniform sampler2DRect tex;
uniform vec2 LensCenter;
uniform vec2 ScreenCenter;
uniform vec2 Scale;
uniform vec2 ScaleIn;
uniform vec4 HmdWarpParam;
uniform int eye;
vec2 HmdWarp(vec2 in01)
{
    vec2 theta;
    //if (eye > 0) {
    //  theta = (in01 - LensCenter) * vec2(4.0f, 2.0f) - vec2(1.0f, 1.0f);
    //} else {
      //return in01;
      theta = (in01 - LensCenter - ((eye - 1) * vec2(-0.25f, 0.0f))) * vec2(4.0f, 2.0f) - vec2(1.0f, 1.0f);
    //}
    float rSq = theta.x * theta.x + theta.y * theta.y;
    vec2 rvector = theta * (
                            HmdWarpParam.x +
                            HmdWarpParam.y * rSq +
                            HmdWarpParam.z * rSq * rSq +
                            HmdWarpParam.w * rSq * rSq * rSq
                           );
    //if (eye > 0) {
    //return (((rvector + vec2(1.0f, 1.0f)) / vec2(4.0f, 2.0f)) + LensCenter) * vec2(0.8f, 0.8f);
    //} else {
      return (((rvector + vec2(1.0f, 1.0f)) / vec2(4.0f, 2.0f)) + LensCenter + ((eye-1) * vec2(-0.375f, 0.0f))) * vec2(0.8f, 0.8f);
    //}
}
void main(void)
{
    vec2 ts = textureSize(tex);
    vec2 tn = texPosition.xy / ts;
    // Test lens center offsetting without warping
    //vec2 tc = vec2(tn.x + ScreenCenter.x - LensCenter.x, tn.y);
    vec2 tc = HmdWarp(tn);

    fragColor = texelFetch(tex, ivec2(tc.x * ts.x, tc.y * ts.y));

    // Test banding for calculating the proper
    // center and scale parameters
    // When running without warping, the bands
    // from the two eyes should align
    // When running with warping, the bands
    // should aling and appear straight
    if (
         ((abs(0.5 - tc.x) > 0.0) && (abs(0.5 - tc.x) < 0.02)) ||
         ((abs(0.5 - tc.x) > 0.48) && (abs(0.5 - tc.x) < 0.5)) ||
         ((tc.y > 0.0) && (tc.y < 0.02)) ||
         ((tc.y > 0.98) && (tc.y < 1.0))
       ) {
        fragColor = vec4(0.0, 0.0, 1.0, 1.0);
    }

    // Clamp the pixels that go outside the eye view
    // tc is in [0,1]
    // tcn is normalized to [-1,1]
    if (eye > 0) {
      vec2 tcn = tc * 2 - 1;
      if (any(notEqual(clamp(tc,
                             ScreenCenter-vec2(0.0,0.0),
                             ScreenCenter+vec2(0.5,1)
                             ) - tc,
                       vec2(0.0, 0.0)
                       )
              )
          )
      {
          // Render a black pixel
          fragColor = vec4(0.0, 0.0, 0.0, 1.0);
      }
    } else {
      if (any(notEqual(clamp(tc, -vec2(0.5,0.0), vec2(1.0,1.0)) - tc,
                       vec2(0.0, 0.0)
                       )
              )
          )
      {
        // Render a black pixel
        fragColor = vec4(0.0, 0.0, 0.0, 1.0);
      }
    }
}
