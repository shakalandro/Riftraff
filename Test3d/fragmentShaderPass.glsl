uniform sampler2D texture;
varying float xpos;
varying float ypos;
void main()
{
    gl_FragColor = vec4(abs(xpos), abs(ypos), 0.0, 1.0);
    //gl_FragColor = texture2D(texture, vec2(xpos, ypos));
    //gl_FragColor = texture2DProj(texture, vec2(xpos, ypos));
    if (((abs(xpos) > 0.48) && (abs(xpos) < 0.52)) ||
        ((abs(ypos) > 0.48) && (abs(ypos) < 0.52))) {
        gl_FragColor = vec4(0.0, 0.0, 1.0, 1.0);
    }
}
