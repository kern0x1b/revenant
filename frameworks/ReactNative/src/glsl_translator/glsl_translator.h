#pragma once

#include <cstddef>
#include <string>

namespace revenant::glsl {

enum class Stage {
    vertex,
    fragment,
};

struct Translation {
    bool ok;
    std::string glsl;
    std::string log;
};

constexpr std::size_t max_source_bytes = 1024 * 1024;

Translation translate_es300(Stage stage, const std::string& source);

}
