#version 150
precision highp float;
in vec3 vertexPosition;
in vec4 texturePosition;
out vec4 texPosition;
out vec4 vertPosition;
void main() {
    texPosition = texturePosition;
    vertPosition = vec4(vertexPosition, 1.0);
    gl_Position = vec4(vertexPosition, 1.0);
}
