#ifdef GL_ES
precision highp float;
#endif

uniform vec3 uLightDir;
uniform vec3 uCameraPos;
uniform vec3 uLightRadiance;
uniform sampler2D uGDiffuse;
uniform sampler2D uGNormalWorld;
uniform sampler2D uGShadow;
uniform sampler2D uGPosWorld;
uniform sampler2D uGDepth[4];

varying mat4 vWorldToScreen;
varying highp vec4 vPosWorld;

#define M_PI 3.1415926535897932384626433832795
#define TWO_PI 6.283185307
#define INV_PI 0.31830988618
#define INV_TWO_PI 0.15915494309

#define BIAS 0.0001

float Rand1(inout float p) {
  p = fract(p * .1031);
  p *= p + 33.33;
  p *= p + p;
  return fract(p);
}

vec2 Rand2(inout float p) {
  return vec2(Rand1(p), Rand1(p));
}

float InitRand(vec2 uv) {
  vec3 p3 = fract(vec3(uv.xyx) * .1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

vec3 SampleHemisphereUniform(inout float s, out float pdf) {
  vec2 uv = Rand2(s);
  float z = uv.x;
  float phi = uv.y * TWO_PI;
  float sinTheta = sqrt(1.0 - z * z);
  vec3 dir = vec3(sinTheta * cos(phi), sinTheta * sin(phi), z);
  pdf = INV_TWO_PI;
  return dir;
}

vec3 SampleHemisphereCos(inout float s, out float pdf) {
  vec2 uv = Rand2(s);
  float z = sqrt(1.0 - uv.x);
  float phi = uv.y * TWO_PI;
  float sinTheta = sqrt(uv.x);
  vec3 dir = vec3(sinTheta * cos(phi), sinTheta * sin(phi), z);
  pdf = z * INV_PI;
  return dir;
}

void LocalBasis(vec3 n, out vec3 b1, out vec3 b2) {
  float sign_ = sign(n.z);
  if(n.z == 0.0) {
    sign_ = 1.0;
  }
  float a = -1.0 / (sign_ + n.z);
  float b = n.x * n.y * a;
  b1 = vec3(1.0 + sign_ * n.x * n.x * a, sign_ * b, -sign_ * n.x);
  b2 = vec3(b, sign_ + n.y * n.y * a, -n.y);
}

vec4 Project(vec4 a) {
  return a / a.w;
}

float GetDepth(vec3 posWorld) {
  float depth = (vWorldToScreen * vec4(posWorld, 1.0)).w;
  return depth;
}

/*
 * Transform point from world space to screen space([0, 1] x [0, 1])
 *
 */
vec2 GetScreenCoordinate(vec3 posWorld) {
  vec2 uv = Project(vWorldToScreen * vec4(posWorld, 1.0)).xy * 0.5 + 0.5;
  return uv;
}

float GetGBufferDepth(vec2 uv) {
  float depth = texture2D(uGDepth[0], uv).x;
  if(depth < 1e-2) {
    depth = 1000.0;
  }
  return depth;
}

vec3 GetGBufferNormalWorld(vec2 uv) {
  vec3 normal = texture2D(uGNormalWorld, uv).xyz;
  return normal;
}

vec3 GetGBufferPosWorld(vec2 uv) {
  vec3 posWorld = texture2D(uGPosWorld, uv).xyz;
  return posWorld;
}

float GetGBufferuShadow(vec2 uv) {
  float visibility = texture2D(uGShadow, uv).x;
  return visibility;
}

vec3 GetGBufferDiffuse(vec2 uv) {
  vec3 diffuse = texture2D(uGDiffuse, uv).xyz;
  diffuse = pow(diffuse, vec3(2.2));
  return diffuse;
}

/*
 * Evaluate diffuse bsdf value.
 *
 * wi, wo are all in world space.
 * uv is in screen space, [0, 1] x [0, 1].
 *
 */
vec3 F(vec2 uv) {
  return GetGBufferDiffuse(uv);
}
float D(vec3 _h) {
  return INV_TWO_PI;
}
float G(vec3 _wi, vec3 _vo, vec3 _h) {
  return 1.0;
}

vec3 EvalDiffuse(vec3 _wi, vec3 _wo, vec2 uv) {
  // vec3 h = (wi + wo) / 2.0;
  // vec3 n = GetGBufferNormalWorld(uv);
  // float r = max(dot(n, wi), 0.0) * max(dot(n, wo), 0.0);
  // if(r < BIAS) {
  //   return vec3(0.0);
  // }
  // return F(uv) * G(wi, wo, h) * D(h) / (4.0 * r);
  return GetGBufferDiffuse(uv) * INV_PI;
}

/*
 * Evaluate directional light with shadow map
 * uv is in screen space, [0, 1] x [0, 1].
 *
 */
vec3 EvalDirectionalLight(vec2 uv) {
  float visibility = GetGBufferuShadow(uv);
  vec3 normal = GetGBufferNormalWorld(uv);
  return visibility * max(dot(uLightDir, normal), 0.0) * uLightRadiance;
}

bool RayMarch(vec3 ori, vec3 dir, out vec3 hitPos) {
  hitPos = ori;
  float step = 0.1;
  float dis = 0.0;
  for(int i = 0; i < 100; i++) {
    hitPos = ori + dir * dis;
    float depth = GetGBufferDepth(GetScreenCoordinate(hitPos));
    if(depth + BIAS < GetDepth(hitPos)) {
      return true;
    }
    dis += step;
  }
  return false;
}

#define SAMPLE_NUM 1

void main() {
  float s = InitRand(gl_FragCoord.xy);

  vec3 pos = vPosWorld.xyz;
  vec3 wo = normalize(uCameraPos - pos);
  vec3 LIndirect = vec3(0.0);
  vec2 uv0 = GetScreenCoordinate(pos);
  vec3 normal = GetGBufferNormalWorld(uv0);

  // vec3 dir = reflect(-wo, normal);
  // vec3 hitPos;
  // if(RayMarch(pos, dir, hitPos)) {
  //   vec2 uv1 = GetScreenCoordinate(hitPos);
  //   LIndirect = EvalDiffuse(uLightDir, -dir, uv1);
  //   // Lind = normalize(hitPos);
  // }
  vec3 diffuse = EvalDiffuse(uLightDir, wo, uv0);
  vec3 t, b;
  LocalBasis(normal, t, b);
  t = normalize(t);
  b = normalize(b);
  mat3 localToWorld = mat3(t, b, normal);
  for(int i = 0; i < SAMPLE_NUM; i++) {
    float pdf = 0.0;
    vec3 local_dir = SampleHemisphereUniform(s, pdf);
    vec3 dir = normalize(localToWorld * local_dir);
    vec3 hitPos;
    if(RayMarch(pos, dir, hitPos)) {
      vec2 uv1 = GetScreenCoordinate(hitPos);
      vec3 LSample = diffuse / pdf * EvalDiffuse(uLightDir, -dir, uv1) * EvalDirectionalLight(uv1);
      LIndirect += LSample;
    }
  }
  LIndirect /= float(SAMPLE_NUM);

  vec3 LDirect = diffuse * EvalDirectionalLight(uv0);
  vec3 L = LDirect + LIndirect;
  vec3 color = pow(clamp(L, vec3(0.0), vec3(1.0)), vec3(1.0 / 2.2));
  // gl_FragColor = vec4(vec3(color.rgb), 1.0);
  
  gl_FragColor = vec4(vec3(texture2D(uGDepth[1], uv0).xxx), 1.0);
}
