attribute vec3 aVertexPosition;
attribute vec3 aNormalPosition;
attribute vec2 aTextureCoord;

uniform mat4 uModelMatrix;
uniform mat4 uViewMatrix;
uniform mat4 uProjectionMatrix;
uniform mat4 uLightMVP;

varying highp vec3 vNormal;
varying highp vec2 vTextureCoord;
varying highp vec4 vFragPos;

void main(void) {

  vNormal = aNormalPosition;
  vTextureCoord = aTextureCoord;
  vFragPos = uLightMVP * vec4(aVertexPosition, 1.0);

  gl_Position = uLightMVP * vec4(aVertexPosition, 1.0);
}