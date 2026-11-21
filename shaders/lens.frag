#version 460 core
#include <flutter/runtime_effect.glsl>

// Lensa liquid glass berbentuk pill (kapsul).
// Urutan uniform float HARUS: uSize(2), uEdge, uStrength, uAberr
uniform vec2 uSize;      // ukuran area filter (px fisik)
uniform float uEdge;     // lebar zona lengkung dari tepi ke dalam
uniform float uStrength; // seberapa jauh isi dibelokkan di tepi
uniform float uAberr;    // pelangi tipis (chromatic aberration) di tepi
uniform sampler2D uTex;

out vec4 fragColor;

void main() {
  vec2 coord = FlutterFragCoord().xy;
  vec2 p = coord - uSize * 0.5;

  // jarak ke tepi kapsul
  float r = uSize.y * 0.5;
  float halfLen = max(uSize.x * 0.5 - r, 0.0);
  vec2 c = vec2(clamp(p.x, -halfLen, halfLen), 0.0);
  vec2 v = p - c;
  float len = max(length(v), 0.0001);
  vec2 n = v / len;
  float depth = r - len; // >0 di dalam kapsul

  // 0 di tengah, naik halus ke 1 di tepi
  float t = clamp(1.0 - depth / uEdge, 0.0, 1.0);
  float bend = t * t * uStrength;

  vec2 s = coord - n * bend;
  vec2 ab = n * uAberr * t;

  vec2 uvR = clamp((s + ab) / uSize, 0.0, 1.0);
  vec2 uvG = clamp(s / uSize, 0.0, 1.0);
  vec2 uvB = clamp((s - ab) / uSize, 0.0, 1.0);

  float rr = texture(uTex, uvR).r;
  vec4 g = texture(uTex, uvG);
  float bb = texture(uTex, uvB).b;

  fragColor = vec4(rr, g.g, bb, g.a);
}
