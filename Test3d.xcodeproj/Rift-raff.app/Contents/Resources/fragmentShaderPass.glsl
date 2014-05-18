#version 150
precision highp float;
in vec4 texPosition;
in vec4 vertPosition;
out vec4 fragColor;
uniform sampler2DRect tex;
void main()
{
    fragColor = texelFetch(tex, ivec2(texPosition.x, texPosition.y));
}
