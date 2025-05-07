vec2 distort(vec2 shadowTexturePosition) {
    float distanceFromPlayer = length(shadowTexturePosition);
    vec2 distortedPosition = shadowTexturePosition / mix(1.0,distanceFromPlayer,0.9);
    return distortedPosition;
}