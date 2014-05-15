#version 150
in vec4 position;
out vec4 fragColor;
uniform sampler2DRect tex;
uniform vec2 LensCenter;
uniform vec2 ScreenCenter;
uniform vec2 Scale;
uniform vec2 ScaleIn;
uniform vec4 HmdWarpParam;
vec2 HmdWarp(vec2 in01)
{
    vec2 theta = (in01 - LensCenter * ScaleIn);
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
    vec2 tc = HmdWarp(vec2(position.x-LensCenter.x, position.y));

    fragColor = vec4(abs(tc.x), abs(tc.y), 0.0, 1.0);
    if (((abs(tc.x) > 0.40) && (abs(tc.x) < 0.50)) ||
        ((abs(tc.y) > 0.40) && (abs(tc.y) < 0.50))) {
        fragColor = vec4(0.0, 0.0, 1.0, 1.0);
    }
    // Render the texture pixel from the distorted coords
    // fragColor = texture(tex, tc);
    if (any(notEqual(clamp(tc,
                           ScreenCenter-vec2(0.5,0.5),
                           ScreenCenter+vec2(0.5,0.5)
                          ) - tc,
                     vec2(0.0, 0.0)
                    )
           )
       )
    {
        // Render a black pixel
        fragColor = vec4(0.0, 0.0, 0.0, 1.0);
    }
}
