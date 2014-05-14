#version 150
in vec4 vertexColor;
out vec4 fragColor;
uniform sampler2DRect tex;
void main()
{
    fragColor = vec4(abs(vertexColor.x), abs(vertexColor.y), 0.0, 1.0);
    //fragColor = texture(tex, vertexColor.xy);
}
