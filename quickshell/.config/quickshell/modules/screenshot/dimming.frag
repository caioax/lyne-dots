#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 selectionRect; // (x, y, width, height)
    vec4 dimColor;      // opaque; dimOpacity sets how dark
    vec4 outlineColor;  // opaque
    float dimOpacity;
    vec2 screenSize;
    float borderRadius;
    float outlineThickness;
};

float sdRoundedBox(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + vec2(r);
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void main() {
    vec4 dim = vec4(dimColor.rgb, 1.0) * dimOpacity;

    // No selection yet: dim everything
    if (selectionRect.z < 1.0 || selectionRect.w < 1.0) {
        fragColor = dim * qt_Opacity;
        return;
    }

    vec2 halfSize = selectionRect.zw / 2.0;
    vec2 center = selectionRect.xy + halfSize;
    vec2 p = qt_TexCoord0 * screenSize - center;
    float radius = min(borderRadius, min(halfSize.x, halfSize.y));
    float dist = sdRoundedBox(p, halfSize, radius);

    // Antialiased masks over one pixel: clear inside, outline ring around
    float outside = smoothstep(-0.5, 0.5, dist);
    float beyondOutline = smoothstep(outlineThickness - 0.5, outlineThickness + 0.5, dist);
    vec4 outline = vec4(outlineColor.rgb, 1.0);

    // Premultiplied: the ring fades into the dim, the inside stays clear
    fragColor = mix(outline, dim, beyondOutline) * outside * qt_Opacity;
}
