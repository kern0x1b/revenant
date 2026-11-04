#ifndef REVENANT_GLSL_TRANSLATOR_H
#define REVENANT_GLSL_TRANSLATOR_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

enum revenant_glsl_stage {
    REVENANT_GLSL_VERTEX = 0,
    REVENANT_GLSL_FRAGMENT = 1,
};

struct revenant_glsl_translation {
    int ok;
    char* glsl;
    size_t glsl_length;
    char* log;
};

__attribute__((visibility("hidden"))) void revenant_glsl_translate_es300(enum revenant_glsl_stage stage, const char* source,
                                                                         size_t length, struct revenant_glsl_translation* result);
__attribute__((visibility("hidden"))) void revenant_glsl_translation_free(struct revenant_glsl_translation* result);

#ifdef __cplusplus
}
#endif

#endif
