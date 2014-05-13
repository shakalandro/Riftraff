varying float xpos;
varying float ypos;
void main(void)
{
  gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
  // gl_TexCoord[0] = gl_MultiTexCoord0;
  xpos = clamp(gl_Vertex.x,0.0,1.0);
  ypos = clamp(gl_Vertex.y,0.0,1.0);
  xpos = clamp(gl_MultiTexCoord0.x,0.0,1.0);
  ypos = clamp(gl_MultiTexCoord0.y,0.0,1.0);
}