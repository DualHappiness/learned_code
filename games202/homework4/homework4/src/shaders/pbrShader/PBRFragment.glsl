#ifdef GL_ES
precision mediump float;
#endif

uniform vec3 uLightPos;
uniform vec3 uCameraPos;
uniform vec3 uLightRadiance;
uniform vec3 uLightDir;

uniform sampler2D uAlbedoMap;
uniform float uMetallic;
uniform float uRoughness;
uniform sampler2D uBRDFLut;
uniform samplerCube uCubeTexture;

varying highp vec2 vTextureCoord;
varying highp vec3 vFragPos;
varying highp vec3 vNormal;

const float PI = 3.14159265359;

float DistributionGGX(vec3 N, vec3 H, float roughness) {
    // To calculate GGX NDF here
    float a = roughness * roughness;
    float a2 = a * a;
    float NdotH = max(0.0, dot(H, N));
    float NdotH2 = NdotH * NdotH;

    float nom = a2;
    float denom = (NdotH2 * (a2 - 1.0) + 1.0);
    denom = PI * denom * denom;
    return nom / max(denom, 0.0001);
}

float GeometrySchlickGGX(float NdotV, float roughness) {
    // To calculate Smith G1 here
    float a = roughness;
    float k = (a * a) / 2.0;

    float nom = NdotV;
    float denom = NdotV * (1.0 - k) + k;

    return nom / denom;
}

float GeometrySmith(vec3 N, vec3 V, vec3 L, float roughness) {
    // To calculate Smith G here
    float ggx1 = GeometrySchlickGGX(dot(N, L), roughness);
    float ggx2 = GeometrySchlickGGX(dot(N, V), roughness);

    return ggx1 * ggx2;
}

vec3 fresnelSchlick(vec3 F0, vec3 V, vec3 H) {
    // To calculate Schlick F here
    return F0 + (1.0 - F0) * pow(1.0 - dot(H, V), 5.0);
}

void main(void) {
    vec3 albedo = pow(texture2D(uAlbedoMap, vTextureCoord).rgb, vec3(2.2));

    vec3 N = normalize(vNormal);
    vec3 V = normalize(uCameraPos - vFragPos);
    float NdotV = max(dot(N, V), 0.0);

    vec3 F0 = vec3(0.04);
    F0 = mix(F0, albedo, uMetallic);

    vec3 Lo = vec3(0.0);

    vec3 L = normalize(uLightDir);
    vec3 H = normalize(V + L);
    float NdotL = max(dot(N, L), 0.0);

    vec3 radiance = uLightRadiance;

    float NDF = DistributionGGX(N, H, uRoughness);
    float G = GeometrySmith(N, V, L, uRoughness);
    vec3 F = fresnelSchlick(F0, V, H);

    vec3 numerator = NDF * G * F;
    float denominator = max((4.0 * NdotL * NdotV), 0.001);
    vec3 BRDF = numerator / denominator;

    Lo += BRDF * radiance * NdotL;
    vec3 color = Lo;

    color = color / (color + vec3(1.0));
    color = pow(color, vec3(1.0 / 2.2));
    gl_FragColor = vec4(color, 1.0);
}