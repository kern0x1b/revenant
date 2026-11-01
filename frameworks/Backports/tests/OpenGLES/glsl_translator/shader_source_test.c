#include <OpenGLES/ES2/gl.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

void glShaderSource(GLuint shader, GLsizei count, const GLchar* const* string, const GLint* length);
void glCompileShader(GLuint shader);
void glGetShaderiv(GLuint shader, GLenum pname, GLint* params);
void glGetShaderInfoLog(GLuint shader, GLsizei bufSize, GLsizei* length, GLchar* infoLog);
void glDeleteShader(GLuint shader);
void revenant_shader_install_system(void (*shader_source)(GLuint, GLsizei, const GLchar* const*, const GLint*),
                                    void (*compile_shader)(GLuint),
                                    void (*get_shaderiv)(GLuint, GLenum, GLint*),
                                    void (*get_shader_info_log)(GLuint, GLsizei, GLsizei*, GLchar*),
                                    void (*delete_shader)(GLuint));

#define SHADERS 8

struct driver_shader {
    GLuint name;
    GLenum type;
    char* source;
    GLint compiled;
    char log[256];
};

static struct driver_shader shaders[SHADERS];
static int driver_compiles;
static int driver_sources;
static int failures;

static struct driver_shader* find(GLuint name)
{
    for (int i = 0; i < SHADERS; ++i)
        if (shaders[i].name == name)
            return &shaders[i];
    return NULL;
}

static void expect(int ok, const char* what)
{
    printf("%s: %s\n", ok ? "ok" : "FAILED", what);
    if (!ok)
        ++failures;
}

static void fake_shader_source(GLuint shader, GLsizei count, const GLchar* const* string, const GLint* length)
{
    struct driver_shader* s = find(shader);
    if (s == NULL)
        return;
    size_t total = 0;
    for (GLsizei i = 0; i < count; ++i)
        total += length && length[i] >= 0 ? (size_t)length[i] : strlen(string[i]);
    free(s->source);
    s->source = malloc(total + 1);
    size_t at = 0;
    for (GLsizei i = 0; i < count; ++i) {
        size_t piece = length && length[i] >= 0 ? (size_t)length[i] : strlen(string[i]);
        memcpy(s->source + at, string[i], piece);
        at += piece;
    }
    s->source[total] = '\0';
    ++driver_sources;
}

static void fake_compile_shader(GLuint shader)
{
    struct driver_shader* s = find(shader);
    if (s == NULL)
        return;
    ++driver_compiles;
    s->compiled = strncmp(s->source, "#version 100", 12) == 0 ? GL_TRUE : GL_FALSE;
    strcpy(s->log, s->compiled ? "" : "driver: not GLSL ES 1.00");
}

static void fake_get_shaderiv(GLuint shader, GLenum pname, GLint* params)
{
    struct driver_shader* s = find(shader);
    if (s == NULL)
        return;
    if (pname == GL_SHADER_TYPE)
        *params = (GLint)s->type;
    else if (pname == GL_COMPILE_STATUS)
        *params = s->compiled;
    else if (pname == GL_INFO_LOG_LENGTH)
        *params = s->log[0] ? (GLint)strlen(s->log) + 1 : 0;
}

static void fake_get_shader_info_log(GLuint shader, GLsizei bufSize, GLsizei* length, GLchar* infoLog)
{
    struct driver_shader* s = find(shader);
    size_t written = 0;
    if (s != NULL && bufSize > 0) {
        written = strlen(s->log);
        if (written > (size_t)(bufSize - 1))
            written = (size_t)(bufSize - 1);
        memcpy(infoLog, s->log, written);
        infoLog[written] = '\0';
    }
    if (length != NULL)
        *length = (GLsizei)written;
}

static void fake_delete_shader(GLuint shader)
{
    struct driver_shader* s = find(shader);
    if (s == NULL)
        return;
    free(s->source);
    memset(s, 0, sizeof *s);
}

static void create(GLuint name, GLenum type)
{
    for (int i = 0; i < SHADERS; ++i) {
        if (shaders[i].name == 0) {
            shaders[i].name = name;
            shaders[i].type = type;
            return;
        }
    }
}

static char* read_file(const char* path)
{
    FILE* in = fopen(path, "rb");
    if (in == NULL)
        return NULL;
    fseek(in, 0, SEEK_END);
    long size = ftell(in);
    fseek(in, 0, SEEK_SET);
    char* text = malloc((size_t)size + 1);
    size_t read = fread(text, 1, (size_t)size, in);
    text[read] = '\0';
    fclose(in);
    return text;
}

static void send(GLuint shader, const char* text)
{
    const GLchar* piece = text;
    GLint length = (GLint)strlen(text);
    glShaderSource(shader, 1, &piece, &length);
}

static int compile_status(GLuint shader)
{
    GLint status = -1;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &status);
    return status;
}

static const char* source_of(GLuint shader)
{
    struct driver_shader* s = find(shader);
    return s != NULL && s->source != NULL ? s->source : "";
}

int main(int argc, char** argv)
{
    const char* root = argc > 1 ? argv[1] : ".";
    revenant_shader_install_system(fake_shader_source, fake_compile_shader, fake_get_shaderiv, fake_get_shader_info_log, fake_delete_shader);

    char path[1024];
    snprintf(path, sizeof path, "%s/corpus/meshbasic.vert", root);
    char* corpus = read_file(path);
    snprintf(path, sizeof path, "%s/expected/meshbasic.vert.es100", root);
    char* expected = read_file(path);
    expect(corpus != NULL && expected != NULL, "the corpus and its expected output are readable");

    create(1, GL_VERTEX_SHADER);
    send(1, corpus);
    expect(strcmp(source_of(1), expected) == 0, "an ES 3.00 corpus shader reaches the driver as its ES 1.00 translation");
    glCompileShader(1);
    expect(driver_compiles == 1 && compile_status(1) == GL_TRUE, "the translated shader compiles in the driver");
    GLint length = -1;
    glGetShaderiv(1, GL_INFO_LOG_LENGTH, &length);
    expect(length == 0, "a shader that compiles has an empty info log");

    const char* broken = "#version 300 es\nprecision highp float;\nout vec4 color;\nvoid main() { color = vec4(undefined_name); }\n";
    create(2, GL_FRAGMENT_SHADER);
    send(2, broken);
    expect(strcmp(source_of(2), broken) == 0, "a shader the translator rejects is passed to the driver unchanged");
    glCompileShader(2);
    expect(driver_compiles == 1, "a rejected shader is not compiled by the driver");
    expect(compile_status(2) == GL_FALSE, "a rejected shader reports GL_FALSE for COMPILE_STATUS");
    glGetShaderiv(2, GL_INFO_LOG_LENGTH, &length);
    expect(length > 1, "a rejected shader has an info log");
    char log[1024];
    GLsizei log_length = -1;
    glGetShaderInfoLog(2, sizeof log, &log_length, log);
    expect(strstr(log, "undefined_name") != NULL, "the info log names the identifier the translator refused");
    expect(log_length == (GLsizei)strlen(log), "the info log length matches the text returned");

    char small[6];
    GLsizei small_length = -1;
    glGetShaderInfoLog(2, sizeof small, &small_length, small);
    expect(small_length == 5 && strlen(small) == 5, "a short buffer receives a truncated, terminated info log");

    const char* plain = "#version 100\nvoid main() { gl_FragColor = vec4(1.0); }\n";
    create(3, GL_FRAGMENT_SHADER);
    send(3, plain);
    expect(strcmp(source_of(3), plain) == 0, "a GLSL ES 1.00 shader is forwarded unchanged");
    glCompileShader(3);
    expect(driver_compiles == 2 && compile_status(3) == GL_TRUE, "a GLSL ES 1.00 shader compiles through the driver");

    const char* lookalike = "#version 300 es2\nvoid main() {}\n";
    create(4, GL_VERTEX_SHADER);
    send(4, lookalike);
    expect(strcmp(source_of(4), lookalike) == 0, "a version line that only starts like ES 3.00 is not translated");

    const GLchar* pieces[2] = {"#version 300 es\n", "precision mediump float;\nvoid main() { gl_Position = vec4(0.0); }\n"};
    create(5, GL_VERTEX_SHADER);
    glShaderSource(5, 2, pieces, NULL);
    glCompileShader(5);
    expect(compile_status(5) == GL_TRUE, "an ES 3.00 shader split into pieces is translated as one shader");

    glDeleteShader(2);
    create(2, GL_FRAGMENT_SHADER);
    send(2, plain);
    glCompileShader(2);
    expect(compile_status(2) == GL_TRUE, "deleting a rejected shader forgets its failure");

    printf("%d failure(s)\n", failures);
    return failures == 0 ? 0 : 1;
}
