// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Transform GLES vertex positions for Vulkan and forward color and
// texture coordinates.

#version 450

layout(location = 0) in vec4 in_position;
layout(location = 1) in vec4 in_color;
layout(location = 2) in vec2 in_texture0;
layout(location = 3) in vec2 in_texture1;
layout(location = 4) in vec2 in_texture2;
layout(location = 5) in vec2 in_texture3;
layout(location = 0) out vec4 primary_color;
layout(location = 1) out vec2 texture0;
layout(location = 2) out vec2 texture1;
layout(location = 3) out vec2 texture2;
layout(location = 4) out vec2 texture3;

void main() {
    gl_Position = vec4(
        in_position.x, -in_position.y, in_position.z, in_position.w);
    primary_color = in_color;
    texture0 = in_texture0;
    texture1 = in_texture1;
    texture2 = in_texture2;
    texture3 = in_texture3;
}
