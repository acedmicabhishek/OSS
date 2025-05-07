#version 460 compatibility

uniform float viewHeight;
uniform float viewWidth;
uniform mat4 gbufferModelView;
uniform mat4 gbufferProjectionInverse;
uniform vec3 fogColor;
uniform vec3 skyColor;
uniform float frameTimeCounter;

in vec4 starData;

float fogify(float x, float w) {
    return w / (x * x + w);
}

vec3 calcSkyColor(vec3 pos) {
    float upDot = dot(pos, gbufferModelView[1].xyz);
    return mix(skyColor, fogColor, fogify(max(upDot, 0.0), 0.25));
}

vec3 screenToView(vec3 screenPos) {
    vec4 ndcPos = vec4(screenPos, 1.0) * 2.0 - 1.0;
    vec4 tmp = gbufferProjectionInverse * ndcPos;
    return tmp.xyz / tmp.w;
}

vec3 generatePurpleStarColor(vec2 fragCoord) {
    // Base purple color
    vec3 basePurple = vec3(0.7, 0.3, 0.9);
    
    // Enhanced twinkle parameters
    float time = frameTimeCounter * 2.5;
    vec2 seed = fragCoord * 0.1;
    
    // Multi-frequency twinkle effect
    float twinkle = 
        0.5 + 0.5 * sin(time + seed.x * 12.9898 + seed.y * 78.233) *
              0.7 + 0.3 * sin(time * 1.5 + seed.y * 45.5432) *
              0.8 + 0.2 * cos(time * 0.8 + seed.x * 34.349);
    
    // Dynamic brightness variation
    float brightness = 0.6 + 0.4 * pow(twinkle, 3.0);
    
    // Apply variations
    vec3 color = basePurple * brightness;
    
    // Gamma correction with flare effect
    return pow(color, vec3(1.0/1.8)) * 1.2;
}

/* DRAWBUFFERS:01 */
layout(location = 0) out vec4 color;
layout(location = 1) out vec4 outColor1;

void main() {
    if (starData.a > 0.5) {
        vec3 purpleStar = generatePurpleStarColor(gl_FragCoord.xy);
        color = vec4(purpleStar, 1.0);
    } else {
        vec3 pos = screenToView(vec3(gl_FragCoord.xy / vec2(viewWidth, viewHeight), 1.0));
        vec3 albedo = calcSkyColor(normalize(pos));
        color = vec4(albedo, 1.0);
        outColor1 = vec4(vec3(0.0), 1.0);
    }
}