#version 120

// Declare a varying variable to receive texture coordinates from the vertex shader.
// This variable is interpolated across the surface of the primitive.
varying vec2 TexCoords;

// Declare a uniform sampler to access the texture bound to the first texture unit.
// 'colortex0' represents the texture that will be sampled.
uniform sampler2D colortex0;
 

#define CONTRAST 1.0 //  [0.2 0.4 0.6 0.8 1.0 1.2 1.4 1.6 1.8 2.0]
#define BRIGHTNESS 1.0 // [0.2 0.4 0.6 0.8 1.0 1.2 1.4 1.6 1.8 2.0]
#define SATURATION 1.0 // [0.2 0.4 0.6 0.8 1.0 1.2 1.4 1.6 1.8 2.0]
#define BLOOM_THRESHOLD 0.8 // [0.2 0.4 0.6 0.8 1.0 1.2 1.4 1.6 1.8 2.0]

void main() {
    // Sample the texture at the current texture coordinates and retrieve the RGB color.
    vec3 color = texture2D(colortex0, TexCoords).rgb;

    // Adjust the contrast of the color.
    // Shift the color range to center around 0.5, scale by CONTRAST, and shift back.
    color = ((color - 0.5) * CONTRAST) + 0.5;

    // Apply brightness adjustment by scaling the color values.
    color.rgb *= vec3(BRIGHTNESS);

    // Convert the color to grayscale using a weighted sum of RGB components.
    // The weights correspond to human perception of red, green, and blue.
    vec3 grey = vec3(dot(vec3(0.2125, 0.7154, 0.0721), color));

    // Interpolate between the grayscale version and the original color
    // based on the SATURATION value. A higher SATURATION retains more color.
    color = mix(grey, color, SATURATION);

    // Calculate the bloom effect by subtracting the BLOOM_THRESHOLD from the color.
    // Clamp the result to ensure no negative values.
    vec3 bloomColor = max(color - BLOOM_THRESHOLD, 0.0);

    // Apply a power function to enhance the bloom effect.
    bloomColor = pow(bloomColor, vec3(2.0));

    // Add the bloom color to the original color to create the final effect.
    color += bloomColor;

    // Output the final color as the fragment color, including an alpha value of 1.0.
    gl_FragColor = vec4(color, 1.0);
}