#version 150
in vec3 vertexPosition;
in vec4 texturePosition;
out vec4 position;
void main() {
    position = texturePosition;
    gl_Position = vec4(vertexPosition, 1.0);
}
