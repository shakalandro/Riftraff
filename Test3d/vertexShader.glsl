varying float xpos;
varying float ypos;
void main()
{
    gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
    gl_TexCoord[0] = gl_TextureMatrix[0] * gl_MultiTexCoord0;

    // Geometry coords
    //xpos = gl_Vertex.x;
    //ypos = gl_Vertex.y;

    // Geometry coords scaled to [-1,1]
    //xpos = gl_Position.x;
    //ypos = gl_Position.y;

    // Texture coords
    //xpos = gl_MultiTexCoord0.x;
    //ypos = gl_MultiTexCoord0.y;

    // Texture coords scaled to [-1,1]
    xpos = gl_TexCoord[0].x;
    ypos = gl_TexCoord[0].y;
}
