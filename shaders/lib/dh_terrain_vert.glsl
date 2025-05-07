#version 460 compatibility

out vec4 blockColor;
out vec2 lightMapCoords;
out vec3 viewSpacePosition;
out vec3 geoNormal;
out vec2 texCoord;
flat out int dh_MaterialId;

void main() {

    dh_MaterialId = dhMaterialId;

    geoNormal = gl_NormalMatrix * gl_Normal;

    blockColor = gl_Color;

    texCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

    lightMapCoords = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;

    viewSpacePosition = (gl_ModelViewMatrix * gl_Vertex).xyz;
    
    gl_Position = ftransform();
}