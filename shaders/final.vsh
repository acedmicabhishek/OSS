#version 120

// Declare a varying variable to pass texture coordinates to the fragment shader.
// 'varying' variables are interpolated across the surface of the primitive.
varying vec2 TexCoords;

void main() {
   // Transform the vertex position using the fixed-function pipeline's
   // model-view-projection matrix. The result is assigned to gl_Position,
   // which determines the final position of the vertex on the screen.
   gl_Position = ftransform();
   
   // Retrieve the texture coordinates from the first texture unit (gl_MultiTexCoord0)
   // and store them in the TexCoords variable. These coordinates will be used in
   // the fragment shader to sample the texture.
   TexCoords = gl_MultiTexCoord0.st;
}
