// Copyright 2019 The Flutter team. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include <flutter/runtime_effect.glsl>

layout(location = 0) uniform float iTime;
layout(location = 1) uniform vec2 iResolution;

layout(location = 0) out vec4 fragColor;

layout(location = 2) uniform sampler2D iChannel0;

void main() {
  vec2 p = FlutterFragCoord().xy/iResolution;
  vec3 c = texture(iChannel0, p).xyz;
  fragColor = vec4(c * iTime, iTime);
}
