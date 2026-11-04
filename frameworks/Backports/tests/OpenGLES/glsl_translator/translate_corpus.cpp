#include "RevenantGLSLTranslator.h"

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

std::string translate(enum revenant_glsl_stage stage, const std::string& source, bool& ok, std::string& log)
{
    struct revenant_glsl_translation result;
    revenant_glsl_translate_es300(stage, source.data(), source.size(), &result);
    ok = result.ok != 0;
    log = result.log != nullptr ? result.log : "";
    std::string glsl = result.glsl != nullptr ? std::string(result.glsl, result.glsl_length) : std::string();
    revenant_glsl_translation_free(&result);
    return glsl;
}

}

int main(int argc, char** argv)
{
    const std::string root = argc > 1 ? argv[1] : ".";
    const std::vector<std::pair<std::string, enum revenant_glsl_stage>> programs = {
        {"meshbasic.vert", REVENANT_GLSL_VERTEX},
        {"meshbasic.frag", REVENANT_GLSL_FRAGMENT},
        {"meshstandard.vert", REVENANT_GLSL_VERTEX},
        {"meshstandard.frag", REVENANT_GLSL_FRAGMENT},
        {"instanced-shadermaterial.vert", REVENANT_GLSL_VERTEX},
        {"instanced-shadermaterial.frag", REVENANT_GLSL_FRAGMENT},
    };

    for (const auto& program : programs) {
        const std::string source = read_file(root + "/corpus/" + program.first);
        const std::string expected = read_file(root + "/expected/" + program.first + ".es100");
        bool ok = false;
        std::string log;
        const std::string glsl = translate(program.second, source, ok, log);
        expect(ok, program.first + " translates: " + log);
        expect(ok && glsl == expected, program.first + " matches the ES 1.00 output of the CLI pipeline");
    }

    bool ok = true;
    std::string log;
    const std::string oversized(1024 * 1024 + 1, ' ');
    translate(REVENANT_GLSL_VERTEX, oversized, ok, log);
    expect(!ok && log.find("REJECTED") != std::string::npos, "a source one byte over the limit is rejected");

    std::printf("%d failure(s)\n", failures);
    return failures == 0 ? 0 : 1;
}
