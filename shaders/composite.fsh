#version 460

const bool colortex0MipmapEnabled = true;

//uniforms
uniform sampler2D colortex0; //inColor
uniform sampler2D colortex1; //specular
uniform sampler2D colortex2; //normals
uniform sampler2D colortex3; //albedo
uniform sampler2D colortex4; //skyLight
uniform sampler2D depthtex0;
#ifdef DISTANT_HORIZONS
uniform sampler2D dhDepthTex0;
#endif

uniform float near;
uniform float far;
#ifdef DISTANT_HORIZONS
uniform float dhNearPlane;
uniform float dhFarPlane;
#endif
uniform float aspectRatio;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;
uniform mat4 gbufferProjection;

uniform vec3 fogColor;
uniform vec3 skyColor;

//vertexToFragment
in vec2 texCoord;

/* DRAWBUFFERS:0 */
layout(location = 0) out vec4 outColor0; //colortex0

struct Ray {
    vec3 origin;
    vec3 direction;
};

float fogify(float x, float w) {
	return w / (x * x + w);
}

vec3 calcSkyColor(vec3 pos) {
	float upDot = dot(pos, gbufferModelView[1].xyz);
	return mix(skyColor, fogColor, fogify(max(upDot, 0.0), 0.25));
}

//functions
float linearizeDepth(float depth, float near, float far) {
    return (near * far) / (depth * (near - far) + far);
}

float unlinearizeDepth(float linearDepth, float near, float far) {
    return (near * far - linearDepth * far) / (linearDepth * (near - far));
}

mat4 perspectiveProjection(float fov, float aspect, float near, float far) {
	float inverseTanFovHalf = 1.0 / tan(fov/ 2);
	
	return mat4(
		inverseTanFovHalf / aspect, 0, 0, 0,
		0, inverseTanFovHalf, 0, 0,
		0, 0, -(far + near) / (far - near), -1,
		0, 0, -2 * far * near / (far - near), 0
	);
}

 #include "/lib/brdf.glsl"

void main() {

    vec4 inputColorData = texture(colortex0,texCoord);
    vec3 inColor = pow(inputColorData.rgb,vec3(2.2));
    float transparency = inputColorData.a;

    vec3 albedo = pow(texture(colortex3,texCoord).rgb,vec3(2.2));

    vec3 skyLight = texture(colortex4,texCoord).rgb;

    float depth = texture(depthtex0,texCoord).r;
    float depthLinear = linearizeDepth(depth,near,far*4);

    #ifdef DISTANT_HORIZONS
    float dhDepth = texture(dhDepthTex0,texCoord).r;
    float dhDepthLinear = linearizeDepth(dhDepth,dhNearPlane,dhFarPlane);
    #endif

    float fov = 2.0 * atan(1.0 / gbufferProjection[1][1]);

    #ifdef DISTANT_HORIZONS
    mat4 customGbufferProjection = perspectiveProjection(fov, aspectRatio, dhNearPlane, dhFarPlane);
    mat4 customGbufferProjectionInverse = inverse(customGbufferProjection);
    bool isFragDH = depth == 1.0;
    vec3 fragScreenSpace = mix(vec3(texCoord,depth),vec3(texCoord,dhDepth),float(isFragDH));
    vec3 fragNdcSpace = fragScreenSpace * 2.0 - 1.0;
    vec4 fragHomogeneousSpace = mix(gbufferProjectionInverse * vec4(fragNdcSpace,1.0),customGbufferProjectionInverse * vec4(fragNdcSpace,1.0),float(isFragDH));
    #else
    vec3 fragScreenSpace = vec3(texCoord,depth);
    vec3 fragNdcSpace = fragScreenSpace * 2.0 - 1.0;
    vec4 fragHomogeneousSpace = gbufferProjectionInverse * vec4(fragNdcSpace,1.0);
    #endif
    vec3 fragViewSpace = fragHomogeneousSpace.xyz/fragHomogeneousSpace.w;

    //material data
    vec3 specularData = texture(colortex1,texCoord).rgb;
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

    vec3 normal = mat3(gbufferModelView) * (texture(colortex2,texCoord).rgb*2.0-1.0);

    vec3 reflectionColor = vec3(0);
    
    if((roughness < .2 && fragScreenSpace.z != 1.0)) {
        
        vec3 viewDirection = normalize(fragViewSpace);
        
        Ray ray;
        
        ray.origin = fragViewSpace + normal * mix(0.01,1.5,smoothstep(0,far,distance(fragViewSpace,vec3(0.0))));
        
        ray.direction = reflect(viewDirection,normal);
        
        
        reflectionColor =  skyLight * pow(calcSkyColor(ray.direction),vec3(2.2));
        
        reflectionColor *= brdf(ray.direction, -viewDirection, roughness, normal, albedo, metallic, reflectance,false,true);
        
        vec3 currentPosition = ray.origin;

        for (int i = 0; i < 1000; i++) {
            
            float stepSize = mix(.02, 5.0, smoothstep(100.0, 1000.0, float(i)));
            
            currentPosition += ray.direction * stepSize;

            vec3 rayCurrentPositionViewSpace = currentPosition;

            #ifdef DISTANT_HORIZONS
            bool isDH = distance(rayCurrentPositionViewSpace,vec3(0)) > far;
            vec4 rayCurrentPositionHomogeneousSpace = mix(gbufferProjection * vec4(rayCurrentPositionViewSpace,1.0),customGbufferProjection * vec4(rayCurrentPositionViewSpace,1.0),float(isDH));
            #else
            vec4 rayCurrentPositionHomogeneousSpace = gbufferProjection * vec4(rayCurrentPositionViewSpace,1.0);
            #endif

            vec3 rayCurrentPositionNdcSpace = rayCurrentPositionHomogeneousSpace.xyz/rayCurrentPositionHomogeneousSpace.w;
            vec3 rayCurrentPositionScreenSpace = rayCurrentPositionNdcSpace * .5 + .5;

            if (rayCurrentPositionScreenSpace.x > 1 || rayCurrentPositionScreenSpace.x < 0 || rayCurrentPositionScreenSpace.y > 1 || rayCurrentPositionScreenSpace.y < 0) {
                break;
            }

            float depthAtRayCurrentPosition = texture(depthtex0,rayCurrentPositionScreenSpace.xy).r;
            float depthAtRayCurrentPositionLinear = linearizeDepth(depthAtRayCurrentPosition,near,far*4);
            #ifdef DISTANT_HORIZONS
            float dhDepthAtRayCurrentPosition = texture(dhDepthTex0,rayCurrentPositionScreenSpace.xy).r;
            float dhDepthAtRayCurrentPositionLinear = linearizeDepth(dhDepthAtRayCurrentPosition,dhNearPlane,dhFarPlane);

            float switchedLinearDepthAtRayCurrentPosition = mix(depthAtRayCurrentPositionLinear,dhDepthAtRayCurrentPositionLinear,float(isDH));
            float linearizedRayDepth = mix(linearizeDepth(rayCurrentPositionScreenSpace.z,near,far*4.0),linearizeDepth(rayCurrentPositionScreenSpace.z,dhNearPlane,dhFarPlane),float(isDH));
            #else
            float switchedLinearDepthAtRayCurrentPosition = depthAtRayCurrentPositionLinear;
            float linearizedRayDepth = linearizeDepth(rayCurrentPositionScreenSpace.z,near,far*4.0);
            #endif
            if (depthAtRayCurrentPosition != 1.0 && linearizedRayDepth > switchedLinearDepthAtRayCurrentPosition && abs(linearizedRayDepth - switchedLinearDepthAtRayCurrentPosition) < stepSize*4.0) {
                float distanceTraveled = distance(currentPosition,ray.origin);
                reflectionColor = pow(texture(colortex0,rayCurrentPositionScreenSpace.xy).rgb,vec3(2.2));
                reflectionColor *= brdf(ray.direction, -viewDirection, roughness, normal, albedo, metallic, reflectance,false,true);
                break;
            }
        }
        
    }
    vec3 outColor = inColor + mix(reflectionColor,vec3(0),pow(roughness,.1));
    
    outColor = pow(outColor,vec3(1/2.2));
    outColor0 = vec4(outColor,transparency);
}
