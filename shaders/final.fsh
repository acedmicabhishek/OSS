#version 120

varying vec2 TexCoords;

uniform sampler2D colortex0;
uniform float viewWidth;
uniform float viewHeight;

// Basic adjustments
#define CONTRAST 1.02
#define BRIGHTNESS 1.1
#define SATURATION 1.05

// FXAA Toggle & Settings
#define FXAA 1 // [0 1]
#define FXAA_SPAN_MAX 8.0
#define FXAA_REDUCE_MUL 0.125
#define FXAA_REDUCE_MIN 0.0078125
#define FXAA_SUBPIX_SHIFT 0.5

// Bloom settings
#define BLOOM_THRESHOLD 0.8 // [0.0 0.2 0.4 0.8 1.0]
#define BLOOM_INTENSITY 0.8

// Advanced effects
#define SHARPEN_INTENSITY 0.0       // [0.0 0.8 1.0 1.2 1.4 1.6 1.8 2.0]
#define VIGNETTE_INTENSITY 0.0     // [0.0 0.3 0.4 0.5 0.6 0.8]
#define COLOR_TEMPERATURE 6500.0  // [4000.0 5500.0 6500.0 7500.0]

vec3 tonemapACES(vec3 x) {
    const float a = 2.51;
    const float b = 0.03;
    const float c = 2.43;
    const float d = 0.59;
    const float e = 0.14;
    return clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0);
}

vec3 adjustTemperature(vec3 color, float temperature) {
    temperature = clamp(temperature, 4000.0, 7500.0) / 6500.0;
    return vec3(
        color.r * (temperature < 1.0 ? 1.0 : 0.8),
        color.g,
        color.b * (temperature > 1.0 ? 1.0 : 1.2)
    );
}

#if FXAA == 1
vec3 applyFXAA(vec2 fragCoord) {
    vec2 inverseRes = 1.0 / vec2(viewWidth, viewHeight);
    vec2 texCoord = fragCoord * inverseRes;
    
    vec3 rgbNW = texture2D(colortex0, texCoord + vec2(-1.0, -1.0) * inverseRes).xyz;
    vec3 rgbNE = texture2D(colortex0, texCoord + vec2(1.0, -1.0) * inverseRes).xyz;
    vec3 rgbSW = texture2D(colortex0, texCoord + vec2(-1.0, 1.0) * inverseRes).xyz;
    vec3 rgbSE = texture2D(colortex0, texCoord + vec2(1.0, 1.0) * inverseRes).xyz;
    vec3 rgbM  = texture2D(colortex0, texCoord).xyz;
    
    float lumaNW = dot(rgbNW, vec3(0.299, 0.587, 0.114));
    float lumaNE = dot(rgbNE, vec3(0.299, 0.587, 0.114));
    float lumaSW = dot(rgbSW, vec3(0.299, 0.587, 0.114));
    float lumaSE = dot(rgbSE, vec3(0.299, 0.587, 0.114));
    float lumaM  = dot(rgbM,  vec3(0.299, 0.587, 0.114));
    
    vec2 dir;
    dir.x = -((lumaNW + lumaNE) - (lumaSW + lumaSE));
    dir.y =  ((lumaNW + lumaSW) - (lumaNE + lumaSE));
    
    float dirReduce = max((lumaNW + lumaNE + lumaSW + lumaSE) * 0.25 * FXAA_REDUCE_MUL, FXAA_REDUCE_MIN);
    float rcpDirMin = 1.0 / (min(abs(dir.x), abs(dir.y)) + dirReduce);
    
    dir = clamp(dir * rcpDirMin, -FXAA_SPAN_MAX, FXAA_SPAN_MAX) * inverseRes;
    
    vec3 rgbA = 0.5 * (
        texture2D(colortex0, texCoord + dir * (0.5 - FXAA_SUBPIX_SHIFT)).xyz +
        texture2D(colortex0, texCoord + dir * (0.5 + FXAA_SUBPIX_SHIFT)).xyz
    );
    
    vec3 rgbB = rgbA * 0.5 + 0.25 * (
        texture2D(colortex0, texCoord + dir * -0.5).xyz +
        texture2D(colortex0, texCoord + dir * 0.5).xyz
    );
    
    float lumaB = dot(rgbB, vec3(0.299, 0.587, 0.114));
    float lumaMin = min(lumaM, min(min(lumaNW, lumaNE), min(lumaSW, lumaSE)));
    float lumaMax = max(lumaM, max(max(lumaNW, lumaNE), max(lumaSW, lumaSE)));
    
    return (lumaB < lumaMin || lumaB > lumaMax) ? rgbA : rgbB;
}
#endif

void main() {
    #if FXAA == 1
    vec3 color = applyFXAA(gl_FragCoord.xy);
    #else
    vec3 color = texture2D(colortex0, TexCoords).rgb;
    #endif

    // Sharpening
    #if SHARPEN_INTENSITY > 0.0
    vec2 texelSize = 1.0 / vec2(viewWidth, viewHeight);
    vec3 sharp = color * 4.0;
    sharp -= texture2D(colortex0, TexCoords + texelSize * vec2(1, 0)).rgb;
    sharp -= texture2D(colortex0, TexCoords - texelSize * vec2(1, 0)).rgb;
    sharp -= texture2D(colortex0, TexCoords + texelSize * vec2(0, 1)).rgb;
    sharp -= texture2D(colortex0, TexCoords - texelSize * vec2(0, 1)).rgb;
    color = mix(color, clamp(sharp, 0.0, 1.0), SHARPEN_INTENSITY);
    #endif

    // Color Processing
    color = adjustTemperature(color, COLOR_TEMPERATURE);
    color = tonemapACES(color);
    color = ((color - 0.5) * CONTRAST) + 0.5;
    color *= BRIGHTNESS;
    
    // Saturation
    vec3 grey = vec3(dot(vec3(0.2125, 0.7154, 0.0721), color));
    color = mix(grey, color, SATURATION);

    // Bloom
    vec3 bloom = max(color - BLOOM_THRESHOLD, 0.0);
    bloom = pow(bloom, vec3(2.0)) * BLOOM_INTENSITY;
    color += bloom;

    // Vignette
    vec2 uv = TexCoords * 2.0 - 1.0;
    float vignette = 1.0 - smoothstep(0.5, 1.5, dot(uv, uv) * VIGNETTE_INTENSITY);
    color *= vignette;

    gl_FragColor = vec4(clamp(color, 0.0, 1.0), 1.0);
}