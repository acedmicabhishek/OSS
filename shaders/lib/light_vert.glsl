#version 460

//attributes
in vec3 vaPosition;
in vec2 vaUV0;
in vec4 vaColor;
in ivec2 vaUV2;
in vec4 at_tangent;
in vec3 mc_Entity;

//uniforms
uniform mat4 modelViewMatrix;
uniform mat4 projectionMatrix;
uniform mat4 gbufferModelViewInverse;
uniform mat3 normalMatrix;

uniform vec3 chunkOffset;
uniform vec3 cameraPosition;

out vec2 texCoord;
out vec3 foliageColor;
out vec2 lightMapCoords;
out vec3 viewSpacePosition;
out vec4 tangent;
out float blockId;

void main() {

    blockId = mc_Entity.x;

    tangent = vec4(normalize(normalMatrix * at_tangent.rgb),at_tangent.a);

    texCoord = vaUV0;

    foliageColor = vaColor.rgb;

    lightMapCoords = vaUV2 * (1.0 / 256.0) + (1.0 / 32.0);

    vec4 viewSpacePositionVec4 = modelViewMatrix * vec4(vaPosition+chunkOffset,1);
    viewSpacePosition = viewSpacePositionVec4.xyz;
    
    gl_Position = projectionMatrix * viewSpacePositionVec4;
}

