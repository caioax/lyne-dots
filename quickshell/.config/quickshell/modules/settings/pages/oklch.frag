#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

// OklchPicker's surfaces. mode 0: chroma (x, share of the most sRGB allows
// at that lightness and hue) by lightness (y, light on top) at `hue`.
// mode 1: the hue strip (x, 0-360) at `lightness` / `chroma`, clipped to sRGB
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;
    float mode;
    float hue;          // degrees
    float lightness;
    float chroma;
    float radius;
};

vec3 oklchToLinear(float L, float C, float h) {
    float rad = radians(h);
    float a = C * cos(rad);
    float b = C * sin(rad);
    float l = L + 0.3963377774 * a + 0.2158037573 * b;
    float m = L - 0.1055613458 * a - 0.0638541728 * b;
    float s = L - 0.0894841775 * a - 1.2914855480 * b;
    l = l * l * l;
    m = m * m * m;
    s = s * s * s;
    return vec3(4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
                -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
                -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s);
}

bool inGamut(vec3 lin) {
    return all(greaterThanEqual(lin, vec3(-0.0001))) && all(lessThanEqual(lin, vec3(1.0001)));
}

// Same search as ThemeGenerator.maxChroma
float maxChroma(float L, float h) {
    float lo = 0.0;
    float hi = 0.4;
    for (int i = 0; i < 16; i++) {
        float mid = (lo + hi) / 2.0;
        if (inGamut(oklchToLinear(L, mid, h)))
            lo = mid;
        else
            hi = mid;
    }
    return lo;
}

vec3 toSrgb(vec3 c) {
    c = clamp(c, 0.0, 1.0);
    vec3 lo = c * 12.92;
    vec3 hi = 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055;
    return mix(hi, lo, step(c, vec3(0.0031308)));
}

float sdRoundedBox(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + vec2(r);
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec3 rgb;
    if (mode < 0.5) {
        float L = 1.0 - uv.y;
        rgb = toSrgb(oklchToLinear(L, uv.x * maxChroma(L, hue), hue));
    } else {
        rgb = toSrgb(oklchToLinear(lightness, chroma, uv.x * 360.0));
    }

    float dist = sdRoundedBox(uv * size - size / 2.0, size / 2.0, radius);
    float inside = 1.0 - smoothstep(-0.5, 0.5, dist);
    fragColor = vec4(rgb, 1.0) * inside * qt_Opacity;
}
