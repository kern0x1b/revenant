#include "RevenantGLSLTranslator.h"

#include <OpenGLES/ES2/gl.h>
#include <dlfcn.h>
#include <pthread.h>
#include <stdlib.h>
#include <string.h>

#define REVENANT_GL_EXPORT __attribute__((visibility("default")))

typedef void (*revenant_shader_source_fn)(GLuint, GLsizei, const GLchar* const*, const GLint*);
typedef void (*revenant_compile_shader_fn)(GLuint);
typedef void (*revenant_get_shaderiv_fn)(GLuint, GLenum, GLint*);
typedef void (*revenant_get_shader_info_log_fn)(GLuint, GLsizei, GLsizei*, GLchar*);
typedef void (*revenant_delete_shader_fn)(GLuint);

struct revenant_shader_failure {
    GLuint shader;
    char* log;
    struct revenant_shader_failure* next;
};

static revenant_shader_source_fn revenant_system_shader_source;
static revenant_compile_shader_fn revenant_system_compile_shader;
static revenant_get_shaderiv_fn revenant_system_get_shaderiv;
static revenant_get_shader_info_log_fn revenant_system_get_shader_info_log;
static revenant_delete_shader_fn revenant_system_delete_shader;

static int revenant_system_installed;
static pthread_once_t revenant_system_once = PTHREAD_ONCE_INIT;
static pthread_mutex_t revenant_failure_lock = PTHREAD_MUTEX_INITIALIZER;
static struct revenant_shader_failure* revenant_failures;

static void revenant_system_load(void)
{
    void* framework = dlopen("/System/Library/Frameworks/OpenGLES.framework/OpenGLES", RTLD_LAZY);
    if (framework == NULL) {
        return;
    }
    revenant_system_shader_source = (revenant_shader_source_fn)dlsym(framework, "glShaderSource");
    revenant_system_compile_shader = (revenant_compile_shader_fn)dlsym(framework, "glCompileShader");
    revenant_system_get_shaderiv = (revenant_get_shaderiv_fn)dlsym(framework, "glGetShaderiv");
    revenant_system_get_shader_info_log = (revenant_get_shader_info_log_fn)dlsym(framework, "glGetShaderInfoLog");
    revenant_system_delete_shader = (revenant_delete_shader_fn)dlsym(framework, "glDeleteShader");
}

static void revenant_system_ensure(void)
{
    if (!revenant_system_installed) {
        pthread_once(&revenant_system_once, revenant_system_load);
    }
}

__attribute__((visibility("hidden"))) void revenant_shader_install_system(revenant_shader_source_fn shader_source,
                                                                          revenant_compile_shader_fn compile_shader,
                                                                          revenant_get_shaderiv_fn get_shaderiv,
                                                                          revenant_get_shader_info_log_fn get_shader_info_log,
                                                                          revenant_delete_shader_fn delete_shader)
{
    revenant_system_shader_source = shader_source;
    revenant_system_compile_shader = compile_shader;
    revenant_system_get_shaderiv = get_shaderiv;
    revenant_system_get_shader_info_log = get_shader_info_log;
    revenant_system_delete_shader = delete_shader;
    revenant_system_installed = 1;
}

static void revenant_failure_forget(GLuint shader)
{
    pthread_mutex_lock(&revenant_failure_lock);
    struct revenant_shader_failure** link = &revenant_failures;
    while (*link != NULL) {
        if ((*link)->shader == shader) {
            struct revenant_shader_failure* gone = *link;
            *link = gone->next;
            free(gone->log);
            free(gone);
            break;
        }
        link = &(*link)->next;
    }
    pthread_mutex_unlock(&revenant_failure_lock);
}

static void revenant_failure_record(GLuint shader, const char* log)
{
    struct revenant_shader_failure* entry = malloc(sizeof *entry);
    if (entry == NULL) {
        return;
    }
    size_t length = strlen(log);
    entry->log = malloc(length + 1);
    if (entry->log == NULL) {
        free(entry);
        return;
    }
    memcpy(entry->log, log, length + 1);
    entry->shader = shader;
    pthread_mutex_lock(&revenant_failure_lock);
    entry->next = revenant_failures;
    revenant_failures = entry;
    pthread_mutex_unlock(&revenant_failure_lock);
}

static int revenant_failure_log(GLuint shader, char** log)
{
    int found = 0;
    *log = NULL;
    pthread_mutex_lock(&revenant_failure_lock);
    for (struct revenant_shader_failure* entry = revenant_failures; entry != NULL; entry = entry->next) {
        if (entry->shader == shader) {
            size_t length = strlen(entry->log);
            *log = malloc(length + 1);
            if (*log != NULL) {
                memcpy(*log, entry->log, length + 1);
                found = 1;
            }
            break;
        }
    }
    pthread_mutex_unlock(&revenant_failure_lock);
    return found;
}

static size_t revenant_piece_length(const GLchar* piece, GLint length)
{
    if (piece == NULL) {
        return 0;
    }
    return length < 0 ? strlen(piece) : (size_t)length;
}

static char* revenant_concatenate(GLsizei count, const GLchar* const* strings, const GLint* lengths, size_t* total)
{
    *total = 0;
    if (count <= 0 || strings == NULL) {
        return NULL;
    }
    size_t sum = 0;
    for (GLsizei i = 0; i < count; ++i) {
        sum += revenant_piece_length(strings[i], lengths ? lengths[i] : -1);
    }
    char* text = malloc(sum + 1);
    if (text == NULL) {
        return NULL;
    }
    size_t at = 0;
    for (GLsizei i = 0; i < count; ++i) {
        size_t piece = revenant_piece_length(strings[i], lengths ? lengths[i] : -1);
        if (piece > 0) {
            memcpy(text + at, strings[i], piece);
            at += piece;
        }
    }
    text[sum] = '\0';
    *total = sum;
    return text;
}

static int revenant_is_es3(const char* text, size_t total)
{
    static const char prefix[] = "#version 300 es";
    const size_t length = sizeof prefix - 1;
    if (total < length || memcmp(text, prefix, length) != 0) {
        return 0;
    }
    if (total == length) {
        return 1;
    }
    const char next = text[length];
    return next == '\n' || next == '\r' || next == ' ' || next == '\t';
}

REVENANT_GL_EXPORT void glShaderSource(GLuint shader, GLsizei count, const GLchar* const* string, const GLint* length)
{
    revenant_system_ensure();
    size_t total = 0;
    char* text = revenant_concatenate(count, string, length, &total);
    revenant_failure_forget(shader);
    if (text != NULL && revenant_is_es3(text, total) && revenant_system_get_shaderiv != NULL && revenant_system_shader_source != NULL) {
        GLint type = 0;
        revenant_system_get_shaderiv(shader, GL_SHADER_TYPE, &type);
        struct revenant_glsl_translation result;
        memset(&result, 0, sizeof result);
        revenant_glsl_translate_es300(type == GL_VERTEX_SHADER ? REVENANT_GLSL_VERTEX : REVENANT_GLSL_FRAGMENT, text, total, &result);
        if (result.ok && result.glsl != NULL) {
            const GLchar* translated = result.glsl;
            GLint translated_length = (GLint)result.glsl_length;
            revenant_system_shader_source(shader, 1, &translated, &translated_length);
        } else {
            revenant_failure_record(shader, result.log != NULL ? result.log : "the GLSL ES 3.00 translation failed");
            if (revenant_system_shader_source != NULL) {
                revenant_system_shader_source(shader, count, string, length);
            }
        }
        revenant_glsl_translation_free(&result);
    } else if (revenant_system_shader_source != NULL) {
        revenant_system_shader_source(shader, count, string, length);
    }
    free(text);
}

REVENANT_GL_EXPORT void glCompileShader(GLuint shader)
{
    revenant_system_ensure();
    char* log = NULL;
    if (revenant_failure_log(shader, &log)) {
        free(log);
        return;
    }
    if (revenant_system_compile_shader != NULL) {
        revenant_system_compile_shader(shader);
    }
}

REVENANT_GL_EXPORT void glGetShaderiv(GLuint shader, GLenum pname, GLint* params)
{
    revenant_system_ensure();
    if (params != NULL && (pname == GL_COMPILE_STATUS || pname == GL_INFO_LOG_LENGTH)) {
        char* log = NULL;
        if (revenant_failure_log(shader, &log)) {
            if (pname == GL_COMPILE_STATUS) {
                *params = GL_FALSE;
            } else {
                *params = log[0] != '\0' ? (GLint)strlen(log) + 1 : 0;
            }
            free(log);
            return;
        }
    }
    if (revenant_system_get_shaderiv != NULL) {
        revenant_system_get_shaderiv(shader, pname, params);
    }
}

REVENANT_GL_EXPORT void glGetShaderInfoLog(GLuint shader, GLsizei bufSize, GLsizei* length, GLchar* infoLog)
{
    revenant_system_ensure();
    char* log = NULL;
    if (revenant_failure_log(shader, &log)) {
        size_t available = bufSize > 0 ? (size_t)(bufSize - 1) : 0;
        size_t written = strlen(log);
        if (written > available) {
            written = available;
        }
        if (bufSize > 0 && infoLog != NULL) {
            memcpy(infoLog, log, written);
            infoLog[written] = '\0';
        }
        if (length != NULL) {
            *length = (GLsizei)written;
        }
        free(log);
        return;
    }
    if (revenant_system_get_shader_info_log != NULL) {
        revenant_system_get_shader_info_log(shader, bufSize, length, infoLog);
    }
}

REVENANT_GL_EXPORT void glDeleteShader(GLuint shader)
{
    revenant_system_ensure();
    revenant_failure_forget(shader);
    if (revenant_system_delete_shader != NULL) {
        revenant_system_delete_shader(shader);
    }
}
