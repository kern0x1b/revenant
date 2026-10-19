// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

#include <glslang/Include/glslang_c_interface.h>
#include <glslang/Public/resource_limits_c.h>

#include <cstddef>
#include <cstdio>
#include <fstream>
#include <iterator>
#include <string>
#include <string_view>

namespace {

int fail(const char* what, const char* detail) {
    std::fprintf(stderr, "glsl_to_spirv: %s%s%s\n", what, detail == nullptr ? "" : "\n", detail == nullptr ? "" : detail);
    return 1;
}

}

int main(int argc, char** argv) {
    if (argc != 4) {
        std::fprintf(stderr, "usage: glsl_to_spirv vert|frag <input> <output>\n");
        return 2;
    }
    const std::string_view kind = argv[1];
    glslang_stage_t stage;
    if (kind == "vert") {
        stage = GLSLANG_STAGE_VERTEX;
    } else if (kind == "frag") {
        stage = GLSLANG_STAGE_FRAGMENT;
    } else {
        return fail("the stage is vert or frag, not ", argv[1]);
    }

    std::ifstream input_file(argv[2], std::ios::binary);
    if (!input_file) {
        return fail("cannot read ", argv[2]);
    }
    const std::string source{std::istreambuf_iterator<char>(input_file), std::istreambuf_iterator<char>()};

    glslang_input_t input{};
    input.language = GLSLANG_SOURCE_GLSL;
    input.stage = stage;
    input.client = GLSLANG_CLIENT_VULKAN;
    input.client_version = GLSLANG_TARGET_VULKAN_1_0;
    input.target_language = GLSLANG_TARGET_SPV;
    input.target_language_version = GLSLANG_TARGET_SPV_1_0;
    input.code = source.c_str();
    input.default_version = 110;
    input.default_profile = GLSLANG_NO_PROFILE;
    input.force_default_version_and_profile = 0;
    input.forward_compatible = 0;
    input.messages = static_cast<glslang_messages_t>(GLSLANG_MSG_SPV_RULES_BIT | GLSLANG_MSG_VULKAN_RULES_BIT);
    input.resource = glslang_default_resource();

    glslang_initialize_process();
    glslang_shader_t* shader = glslang_shader_create(&input);
    if (glslang_shader_preprocess(shader, &input) == 0 || glslang_shader_parse(shader, &input) == 0) {
        const int status = fail(argv[2], glslang_shader_get_info_log(shader));
        glslang_shader_delete(shader);
        glslang_finalize_process();
        return status;
    }
    glslang_program_t* program = glslang_program_create();
    glslang_program_add_shader(program, shader);
    if (glslang_program_link(program, GLSLANG_MSG_SPV_RULES_BIT | GLSLANG_MSG_VULKAN_RULES_BIT) == 0) {
        const int status = fail(argv[2], glslang_program_get_info_log(program));
        glslang_program_delete(program);
        glslang_shader_delete(shader);
        glslang_finalize_process();
        return status;
    }
    glslang_program_SPIRV_generate(program, stage);
    if (const char* messages = glslang_program_SPIRV_get_messages(program); messages != nullptr && *messages != '\0') {
        std::fprintf(stderr, "%s", messages);
    }

    const std::size_t size = glslang_program_SPIRV_get_size(program);
    const unsigned int* words = glslang_program_SPIRV_get_ptr(program);
    std::string text = "{";
    char word[16];
    for (std::size_t i = 0; i < size; ++i) {
        std::snprintf(word, sizeof word, i + 1 < size ? "0x%08x," : "0x%08x", words[i]);
        text += word;
        if (i % 8 == 7) {
            text += '\n';
        }
    }
    text += "}\n";
    glslang_program_delete(program);
    glslang_shader_delete(shader);
    glslang_finalize_process();

    std::ofstream output_file(argv[3], std::ios::binary | std::ios::trunc);
    output_file << text;
    if (!output_file) {
        return fail("cannot write ", argv[3]);
    }
    return 0;
}
