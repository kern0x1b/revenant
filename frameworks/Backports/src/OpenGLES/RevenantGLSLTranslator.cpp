#include "RevenantGLSLTranslator.h"

#include "glslang/Public/ResourceLimits.h"
#include "glslang/Public/ShaderLang.h"
#include "glslang/SPIRV/GlslangToSpv.h"
#include "spirv_cross/spirv_glsl.hpp"

#include <cstdlib>
#include <cstring>
#include <exception>
#include <string>
#include <utility>
#include <vector>

namespace {

constexpr std::size_t max_source_bytes = 1024 * 1024;

struct Translation {
    bool ok;
    std::string glsl;
    std::string log;
};

std::string replace_all(const std::string& text, const std::string& from, const std::string& to)
{
    std::string out;
    std::size_t start = 0;
    for (;;) {
        std::size_t hit = text.find(from, start);
        if (hit == std::string::npos) {
            out.append(text, start, std::string::npos);
            return out;
        }
        out.append(text, start, hit - start);
        out.append(to);
        start = hit + from.size();
    }
}

std::string to_es310(const std::string& source)
{
    std::string renamed = replace_all(source, "average(", "revenant_average(");
    const std::string es300 = "#version 300 es\n";
    if (renamed.compare(0, es300.size(), es300) == 0) {
        renamed.replace(0, es300.size(), "#version 310 es\n");
    }
    return renamed;
}

EShLanguage language_of(enum revenant_glsl_stage stage)
{
    return stage == REVENANT_GLSL_VERTEX ? EShLangVertex : EShLangFragment;
}

bool initialize()
{
    static const bool initialized = glslang::InitializeProcess();
    return initialized;
}

Translation translate(enum revenant_glsl_stage stage, const std::string& source)
{
    if (source.size() > max_source_bytes) {
        return Translation{false, std::string(), "REJECTED: the source is over the source limit"};
    }
    if (!initialize()) {
        return Translation{false, std::string(), "glslang failed to initialize"};
    }

    const EShLanguage language = language_of(stage);
    const std::string text = to_es310(source);
    const char* strings[] = {text.c_str()};
    const EShMessages messages = static_cast<EShMessages>(EShMsgDefault | EShMsgSpvRules);

    glslang::TShader shader(language);
    shader.setStrings(strings, 1);
    shader.setEnvInput(glslang::EShSourceGlsl, language, glslang::EShClientOpenGL, 100);
    shader.setEnvClient(glslang::EShClientOpenGL, glslang::EShTargetOpenGL_450);
    shader.setEnvTarget(glslang::EShTargetSpv, glslang::EShTargetSpv_1_0);
    shader.setAutoMapLocations(true);

    if (!shader.parse(GetDefaultResources(), 100, false, messages)) {
        return Translation{false, std::string(), shader.getInfoLog()};
    }

    glslang::TProgram program;
    program.addShader(&shader);
    if (!program.link(messages)) {
        return Translation{false, std::string(), program.getInfoLog()};
    }
    if (!program.mapIO()) {
        return Translation{false, std::string(), program.getInfoLog()};
    }

    glslang::SpvOptions options;
    options.generateDebugInfo = false;
    options.stripDebugInfo = false;
    options.disableOptimizer = false;
    options.optimizeSize = false;
    options.disassemble = false;
    options.validate = false;
    options.compileOnly = false;

    std::vector<unsigned int> spirv;
    glslang::GlslangToSpv(*program.getIntermediate(language), spirv, &options);

    try {
        spirv_cross::CompilerGLSL compiler(std::move(spirv));
        spirv_cross::CompilerGLSL::Options common = compiler.get_common_options();
        common.es = true;
        common.version = 100;
        compiler.set_common_options(common);
        return Translation{true, compiler.compile(), std::string()};
    } catch (const std::exception& error) {
        return Translation{false, std::string(), error.what()};
    }
}

char* copy_out(const std::string& text, size_t* length)
{
    char* out = static_cast<char*>(std::malloc(text.size() + 1));
    if (out == nullptr) {
        return nullptr;
    }
    std::memcpy(out, text.c_str(), text.size() + 1);
    *length = text.size();
    return out;
}

}

extern "C" void revenant_glsl_translate_es300(enum revenant_glsl_stage stage, const char* source, size_t length,
                                              struct revenant_glsl_translation* result)
{
    result->ok = 0;
    result->glsl = nullptr;
    result->glsl_length = 0;
    result->log = nullptr;
    try {
        const std::string text(source == nullptr ? "" : source, length);
        Translation translation = translate(stage, text);
        result->ok = translation.ok ? 1 : 0;
        size_t log_length = 0;
        result->glsl = copy_out(translation.glsl, &result->glsl_length);
        result->log = copy_out(translation.log, &log_length);
    } catch (...) {
        result->ok = 0;
    }
}

extern "C" void revenant_glsl_translation_free(struct revenant_glsl_translation* result)
{
    std::free(result->glsl);
    std::free(result->log);
    result->glsl = nullptr;
    result->log = nullptr;
    result->glsl_length = 0;
}
