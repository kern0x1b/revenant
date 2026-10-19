// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Classify compositor shader interfaces by their varying and uniform
// contracts.

#pragma once

#include <algorithm>
#include <array>
#include <string_view>

namespace shade {

// Conventional compositor shaders expose either a single color varying or
// indexed color varyings and fragment outputs. Select from shader declarations,
// independently of the process, device or firmware that supplied the program.
struct GlesProgramInterfaceProfile {
    std::string_view color_attribute { "vertex_color" };
    std::string_view color_varying { "color" };
    std::string_view fragment_output { "gl_FragColor" };

    // Compositor shaders spell their inputs by these names. A program that
    // uses them is run by the renderer's fixed-function adapter, not by the
    // GLSL interpreter.
    [[nodiscard]] static bool recognizes(std::string_view source)
    {
        constexpr std::array names { std::string_view { "vertex_position" },
            std::string_view { "vertex_color" },
            std::string_view { "vertex_texcoord" },
            std::string_view { "function_arg" },
            std::string_view { "sampler2DRect" }, std::string_view { "texmat" },
            std::string_view { "texscale" } };
        return std::any_of(names.begin(), names.end(),
            [&](std::string_view name) {
                return source.find(name) != std::string_view::npos;
            });
    }

    [[nodiscard]] static GlesProgramInterfaceProfile from_sources(
        std::string_view vertex, std::string_view fragment)
    {
        GlesProgramInterfaceProfile result;
        if (vertex.find("vertex_color0") != std::string_view::npos) {
            result.color_attribute = "vertex_color0";
            result.color_varying = "color0";
        }
        if (fragment.find("gl_FragData[0]") != std::string_view::npos)
            result.fragment_output = "gl_FragData[0]";
        return result;
    }
};

} // namespace shade
