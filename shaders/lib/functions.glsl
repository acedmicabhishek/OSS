
//functions
#include "/lib/distort.glsl"
#include "/lib/brdf.glsl"
mat3 tbnNormalTangent(vec3 normal, vec3 tangent) {
    vec3 bitangent = normalize(cross(tangent,normal));
    return mat3(tangent, bitangent, normal);
}

vec3 lightingCalculations(vec3 albedo,vec3 tangent, vec3 normalWorldSpace, vec3 worldGeoNormal, vec3 skyLight,vec3 fragFeetPlayerSpace,vec3 fragWorldSpace) {
        
    //material data
    vec4 specularData = texture(specular,texCoord);
    float perceptualSmoothness = specularData.r;
    float metallic = 0.0;
    vec3 reflectance = vec3(0);
    if (specularData.g*255 > 229) {
        metallic = 1.0;
        reflectance = albedo;
    } else {
        reflectance = vec3(specularData.g);
    }
    float roughness = pow(1.0 - perceptualSmoothness, 2.0);
    float smoothness = 1-roughness;

    //space conversion
    vec3 adjustFragFeetPlayerSpace = fragFeetPlayerSpace + worldGeoNormal * .03;
    vec3 fragShadowViewSpace = (shadowModelView * vec4(adjustFragFeetPlayerSpace,1.0)).xyz;
    vec4 fragHomogeneousSpace = shadowProjection * vec4(fragShadowViewSpace,1.0);
    vec3 fragShadowNdcSpace = fragHomogeneousSpace.xyz/fragHomogeneousSpace.w;
    vec3 distortedFragShadowNdcSpace = vec3(distort(fragShadowNdcSpace.xy),fragShadowNdcSpace.z);
    vec3 fragShadowScreenSpace = distortedFragShadowNdcSpace * 0.5 + 0.5;


    //directions
    vec3 shadowLightDirection =  normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);
    vec3 reflectionDirection = reflect(-shadowLightDirection,normalWorldSpace);
    vec3 viewDirection = normalize(cameraPosition - fragWorldSpace);

    //shadow
    float isInShadow = step(fragShadowScreenSpace.z,texture(shadowtex0,fragShadowScreenSpace.xy).r);
    float isInNonColoredShadow = step(fragShadowScreenSpace.z,texture(shadowtex1,fragShadowScreenSpace.xy).r);
    vec3 shadowColor = pow(texture(shadowcolor0,fragShadowScreenSpace.xy).rgb,vec3(2.2));

    vec3 shadowMultiplier = vec3(1.0);

    if(isInShadow == 0.0) {
        if(isInNonColoredShadow == 0.0) {
            shadowMultiplier = vec3(0.0);
        } else { //if fragment is in colored shadow
            shadowMultiplier = shadowColor;
        }
    }

    float distanceFromPlayer = distance(fragFeetPlayerSpace,vec3(0));

    float shadowFade = clamp(smoothstep(100,150,distanceFromPlayer),0.0,1.0);

    shadowMultiplier = mix(shadowMultiplier,vec3(1.0),shadowFade);
    
    //ambient lighting
    vec3 ambientLightDirection = worldGeoNormal;
    vec3 blockLight = pow(texture(lightmap,vec2(lightMapCoords.x,1.0/32.0)).rgb,vec3(2.2));
    vec3 ambientLight = (blockLight + .2*skyLight) * brdf(ambientLightDirection, viewDirection, roughness, normalWorldSpace, albedo, metallic, reflectance,true,false);

    //brdf
    vec3 outputColor = ambientLight + skyLight*shadowMultiplier*brdf(shadowLightDirection, viewDirection, roughness, normalWorldSpace, albedo, metallic, reflectance,false,false);
    if (renderStage == MC_RENDER_STAGE_PARTICLES) {
        outputColor = ambientLight + skyLight*albedo;
    }
    return outputColor;
}