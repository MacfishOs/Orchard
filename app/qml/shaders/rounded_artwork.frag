/*
 * Copyright (C) 2026 SFG545
 *
 * This file is part of Orchard.
 *
 * Orchard is free software: you can redistribute it and/or modify it under the
 * terms of the GNU Affero General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option) any
 * later version.
 *
 * Orchard is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
 * A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
 * details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with Orchard. If not, see <https://www.gnu.org/licenses/>.
 */

#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;
    vec2 cropScale;
    float radius;
    float bottomRadius;
};

layout(binding = 1) uniform sampler2D source;

void main() {
    vec2 p = qt_TexCoord0 * size;
    vec2 half_ = size * 0.5;
    float r = min(p.y < half_.y ? radius : bottomRadius, min(half_.x, half_.y));
    vec2 q = abs(p - half_) - (half_ - r);
    float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
    float alpha = clamp(0.5 - d / max(fwidth(d), 1e-4), 0.0, 1.0);
    // Center crop matches Image.PreserveAspectCrop on the full source texture.
    vec2 uv = 0.5 + (qt_TexCoord0 - 0.5) * cropScale;
    fragColor = texture(source, uv) * alpha * qt_Opacity;
}
