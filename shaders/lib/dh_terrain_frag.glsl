#version 460 compatibility

//uniforms
uniform sampler2D lightmap;
uniform sampler2D depthtex0;
uniform sampler2D dhDepthTex0;
uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor0;
uniform sampler2D specular;
uniform sampler2D normals;

uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowModelView;

uniform float viewHeight;
uniform float viewWidth;
uniform float near;
uniform float far;
uniform float dhNearPlane;
uniform float dhFarPlane;
uniform vec3 fogColor;
uniform vec3 shadowLightPosition;
uniform vec3 cameraPosition;

//vertexToFragment
in vec4 blockColor;
in vec2 lightMapCoords;
in vec3 viewSpacePosition;
in vec3 geoNormal;
in vec2 texCoord;
flat in int dh_MaterialId;

/* DRAWBUFFERS:0124 */
layout(location = 0) out vec4 outColor0; //colortex0 - outcolor
layout(location = 1) out vec4 outColor1; //colortex1 - specular
layout(location = 2) out vec4 outColor2; //colortex2 - normal
layout(location = 3) out vec4 outColor4; //colortex4 - skyLight


//functions
float linearizeDepth(float depth, float near, float far) {
    return (near * far) / (depth * (near - far) + far);
}

#include "functions.glsl"

void main() {

    //input color
    vec4 outputColorData = blockColor;
    vec3 albedo = pow(outputColorData.rgb,vec3(2.2));
    float transparency = outputColorData.a;

    if (transparency < .1) {
        discard;
    }

    vec3 fragFeetPlayerSpace = (gbufferModelViewInverse * vec4(viewSpacePosition,1.0)).xyz;
    vec3 fragWorldSpace = fragFeetPlayerSpace + cameraPosition;

    vec3 tangent = mat3(gbufferModelViewInverse) * normalize(cross(geoNormal, vec3(0, 1, 1)));

    vec3 worldGeoNormal = mat3(gbufferModelViewInverse) * geoNormal;

    vec3 skyLight = pow(texture(lightmap,vec2(1.0/32.0,lightMapCoords.y)).rgb,vec3(2.2));

    vec3 outputColor = lightingCalculations(albedo, tangent,worldGeoNormal,worldGeoNormal,skyLight,fragFeetPlayerSpace,fragWorldSpace);
    
    //depth testing
    vec2 texCoord = gl_FragCoord.xy / vec2(viewWidth,viewHeight);
    float depth = texture(depthtex0,texCoord).r;
    float dhDepth = gl_FragCoord.z;
    float depthLinear = linearizeDepth(depth,near,far*4);
    float dhDepthLinear = linearizeDepth(dhDepth,dhNearPlane,dhFarPlane);
    if (depthLinear < dhDepthLinear && depth != 1) {
        discard;
    }

    //dh blend
    float distanceFromCamera = distance(viewSpacePosition,vec3(0));
    float dhBlend = pow(smoothstep(far-.5*far,far,distanceFromCamera),.6);
    transparency = mix(0.0,transparency,dhBlend);

    float perceptualSmoothness = 0.0;
    float reflectance = 0.0;
    if (dh_MaterialId == DH_BLOCK_WATER) {
        perceptualSmoothness = .99;
        reflectance = 0.036;
    }

    //output color
    outColor0 = vec4(pow(outputColor,vec3(1/2.2)),transparency);
    outColor1 = vec4(perceptualSmoothness, reflectance,1.0,1.0);
    outColor2 = vec4(worldGeoNormal*.5+.5,1.0);//colortex2 - normal
    outColor4 = vec4(skyLight,1.0); //colortex4 - skyLight
}