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
vec2 HmdWarp(vec2 in01)
{
    vec2 theta = (in01 - LensCenter) * ScaleIn;
    float rSq = theta.x * theta.x + theta.y * theta.y;
    vec2 rvector = theta * (
                            HmdWarpParam.x +
                            HmdWarpParam.y * rSq +
                            HmdWarpParam.z * rSq * rSq +
                            HmdWarpParam.w * rSq * rSq * rSq
                           );
    return LensCenter + Scale * rvector;
}
void main(void)
{
    vec2 ts = textureSize(tex);
    vec2 tn = texPosition.xy / ts;
    // Test lens center offsetting without warping
    vec2 tc = vec2(tn.x + ScreenCenter.x - LensCenter.x, tn.y);
    //vec2 tc = HmdWarp(tn);

    fragColor = texelFetch(tex, ivec2(tc.x * ts.x, tc.y * ts.y));

    // Test banding for calculating the proper
    // center and scale parameters
    // When running without warping, the bands
    // from the two eyes should align
    // When running with warping, the bands
    // should aling and appear straight
    if (
         ((abs(0.5 - tc.x) > 0.14) && (abs(0.5 - tc.x) < 0.16)) ||
         ((abs(0.5 - tc.x) > 0.34) && (abs(0.5 - tc.x) < 0.36)) ||
         ((tc.y > 0.24) && (tc.y < 0.26)) ||
         ((tc.y > 0.74) && (tc.y < 0.76))
       ) {
        fragColor = vec4(0.0, 0.0, 1.0, 1.0);
    }

    // Clamp the pixels that go outside the eye view
    // tc is in [0,1]
    // tcn is normalized to [-1,1]
//    vec2 tcn = tc * 2 - 1;
//    if (any(notEqual(clamp(tcn,
//                           ScreenCenter-vec2(0.5,1),
//                           ScreenCenter+vec2(0.5,1)
//                          ) - tcn,
//                     vec2(0.0, 0.0)
//                    )
//            )
//        )
//    {
//        // Render a black pixel
//        fragColor = vec4(0.0, 0.0, 0.0, 1.0);
//    }
}
