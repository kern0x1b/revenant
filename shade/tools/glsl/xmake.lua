-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.

if has_config("shade_vulkan") then
    target("shade_glsl_to_spirv")
        set_kind("binary")
        add_files("glsl_to_spirv.cpp")
        set_policy("build.fence", true)
        add_packages("glslang")
end
