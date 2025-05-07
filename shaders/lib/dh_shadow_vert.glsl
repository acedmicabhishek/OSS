#version 460 compatibility

out vec2 texCoord;
out vec3 foliageColor;

#include "/lib/distort.glsl"

void main() {

    texCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

    foliageColor = gl_Color.rgb;

    gl_Position = ftransform();
    gl_Position.xy = distort(gl_Position.xy);
}