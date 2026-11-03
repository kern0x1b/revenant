#include "glsl_translator.h"

#include <cstdio>
#include <fstream>
#include <sstream>
#include <string>
#include <utility>
#include <vector>

namespace {

int failures = 0;

std::string read_file(const std::string& path)
{
    std::ifstream in(path, std::ios::binary);
    std::stringstream text;
    text << in.rdbuf();
    return text.str();
}

void expect(bool ok, const std::string& what)
{
    std::printf("%s: %s\n", ok ? "ok" : "FAILED", what.c_str());
    if (!ok)
        ++failures;
}

}

int main(int argc, char** argv)
{
    const std::string root = argc > 1 ? argv[1] : ".";
    const std::vector<std::pair<std::string, revenant::glsl::Stage>> programs = {
        {"meshbasic.vert", revenant::glsl::Stage::vertex},
        {"meshbasic.frag", revenant::glsl::Stage::fragment},
        {"meshstandard.vert", revenant::glsl::Stage::vertex},
        {"meshstandard.frag", revenant::glsl::Stage::fragment},
        {"instanced-shadermaterial.vert", revenant::glsl::Stage::vertex},
        {"instanced-shadermaterial.frag", revenant::glsl::Stage::fragment},
    };

    for (const auto& program : programs) {
        const std::string source = read_file(root + "/corpus/" + program.first);
        const std::string expected = read_file(root + "/expected/" + program.first + ".es100");
        const revenant::glsl::Translation result = revenant::glsl::translate_es300(program.second, source);
        expect(result.ok, program.first + " translates: " + result.log);
        expect(result.ok && result.glsl == expected, program.first + " matches the ES 1.00 output of the CLI pipeline");
    }

    const std::string oversized(revenant::glsl::max_source_bytes + 1, ' ');
    const revenant::glsl::Translation rejected = revenant::glsl::translate_es300(revenant::glsl::Stage::vertex, oversized);
    expect(!rejected.ok && rejected.log.find("REJECTED") != std::string::npos, "a source one byte over the limit is rejected");

    std::printf("%d failure(s)\n", failures);
    return failures == 0 ? 0 : 1;
}
