#version 150
in vec4 position;
out vec4 fragColor;
uniform sampler2DRect tex;
void main()
{
    fragColor = vec4(abs(position.x), abs(position.y), 0.0, 1.0) +
                texture(tex, position.xy);
}
