uniform sampler2D texture;
varying float xpos;
varying float ypos;
void main()
{
  gl_FragColor = vec4(xpos, ypos, 0.0, 1.0);
  // gl_FragColor = texture2D(texture, vec2(xpos, ypos));
  // gl_FragColor = texture2DProj(texture, vec2(xpos, ypos));
  // gl_FragColor = texture2DProj(texture, vec2(gl_TexCoord[0]));
}