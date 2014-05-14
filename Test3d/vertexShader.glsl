#version 150
in vec3 inPosition;
in vec4 inColor;
out vec4 vertexColor;
void main() {
    vertexColor = inColor;
    gl_Position = vec4(inPosition, 1.0);
//    varying float xpos;
//    varying float ypos;
//    xpos = clamp(inPosition.x,0.0,1.0);
//    ypos = clamp(inPosition.ypos,0.0,1.0);
}
