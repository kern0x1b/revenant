#import <Foundation/Foundation.h>
#include <math.h>
#include <string.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>

static NSString *REVENANT_ROOT;
static NSMutableString *REVENANT_LOG;
static NSUInteger REVENANT_FAILURES;

static void revenant_flush(void)
{
    [REVENANT_LOG writeToFile:[REVENANT_ROOT stringByAppendingPathComponent:@"probe.txt"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
}

static NSString *revenant_one_line(NSString *text)
{
    NSString *flat = [[text componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]] componentsJoinedByString:@" | "];
    return flat.length > 600 ? [[flat substringToIndex:600] stringByAppendingString:@"..."] : flat;
}

static NSString *revenant_log(GLuint object, BOOL program)
{
    GLint length = 0;
    if (program)
        glGetProgramiv(object, GL_INFO_LOG_LENGTH, &length);
    else
        glGetShaderiv(object, GL_INFO_LOG_LENGTH, &length);
    if (length <= 1)
        return @"";
    GLchar *buffer = malloc(length);
    if (program)
        glGetProgramInfoLog(object, length, NULL, buffer);
    else
        glGetShaderInfoLog(object, length, NULL, buffer);
    NSString *text = [NSString stringWithUTF8String:buffer] ?: @"";
    free(buffer);
    return text;
}

static GLuint revenant_compile(GLenum type, NSString *source, BOOL *compiled, NSString **log)
{
    GLuint shader = glCreateShader(type);
    const char *text = [source UTF8String];
    glShaderSource(shader, 1, &text, NULL);
    glCompileShader(shader);
    GLint status = GL_FALSE;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &status);
    *compiled = status == GL_TRUE;
    *log = revenant_log(shader, NO);
    return shader;
}

static void revenant_program(NSString *name, NSString *stage, NSString *translated, NSString *companion)
{
    BOOL vertexStage = [stage isEqualToString:@"vertex"];
    GLenum translatedType = vertexStage ? GL_VERTEX_SHADER : GL_FRAGMENT_SHADER;
    GLenum companionType = vertexStage ? GL_FRAGMENT_SHADER : GL_VERTEX_SHADER;
    BOOL translatedOK = NO, companionOK = NO;
    NSString *translatedLog = @"", *companionLog = @"";
    CFAbsoluteTime started = CFAbsoluteTimeGetCurrent();
    GLuint shaderTranslated = revenant_compile(translatedType, translated, &translatedOK, &translatedLog);
    GLuint shaderCompanion = revenant_compile(companionType, companion, &companionOK, &companionLog);
    double compileMilliseconds = (CFAbsoluteTimeGetCurrent() - started) * 1000.0;
    BOOL linked = NO;
    GLint uniforms = 0;
    NSString *linkLog = @"";
    if (translatedOK && companionOK) {
        GLuint program = glCreateProgram();
        glAttachShader(program, shaderTranslated);
        glAttachShader(program, shaderCompanion);
        glLinkProgram(program);
        GLint status = GL_FALSE;
        glGetProgramiv(program, GL_LINK_STATUS, &status);
        linked = status == GL_TRUE;
        glGetProgramiv(program, GL_ACTIVE_UNIFORMS, &uniforms);
        linkLog = revenant_log(program, YES);
        glDeleteProgram(program);
    }
    GLenum error = glGetError();
    if (!translatedOK || !linked)
        REVENANT_FAILURES++;
    [REVENANT_LOG appendFormat:@"%@ %@ %@ translated=%@ companion=%@ link=%@ uniforms=%d compile_ms=%.1f glerror=%x\n",
        translatedOK && linked ? @"PASS" : @"FAIL", name, stage,
        translatedOK ? @"ok" : @"fail", companionOK ? @"ok" : @"fail", linked ? @"ok" : @"fail",
        (int)uniforms, compileMilliseconds, error];
    if (translatedLog.length)
        [REVENANT_LOG appendFormat:@"  translated log: %@\n", revenant_one_line(translatedLog)];
    if (companionLog.length && !companionOK)
        [REVENANT_LOG appendFormat:@"  companion log: %@\n", revenant_one_line(companionLog)];
    if (linkLog.length)
        [REVENANT_LOG appendFormat:@"  link log: %@\n", revenant_one_line(linkLog)];
    glDeleteShader(shaderTranslated);
    glDeleteShader(shaderCompanion);
    revenant_flush();
}

static void revenant_limits(void)
{
    GLint value = 0;
    static const struct { const char *name; GLenum pname; } integers[] = {
        {"GL_MAX_VERTEX_ATTRIBS", GL_MAX_VERTEX_ATTRIBS},
        {"GL_MAX_VERTEX_UNIFORM_VECTORS", GL_MAX_VERTEX_UNIFORM_VECTORS},
        {"GL_MAX_FRAGMENT_UNIFORM_VECTORS", GL_MAX_FRAGMENT_UNIFORM_VECTORS},
        {"GL_MAX_VARYING_VECTORS", GL_MAX_VARYING_VECTORS},
        {"GL_MAX_TEXTURE_IMAGE_UNITS", GL_MAX_TEXTURE_IMAGE_UNITS},
        {"GL_MAX_VERTEX_TEXTURE_IMAGE_UNITS", GL_MAX_VERTEX_TEXTURE_IMAGE_UNITS},
        {"GL_MAX_TEXTURE_SIZE", GL_MAX_TEXTURE_SIZE},
        {"GL_NUM_SHADER_BINARY_FORMATS", GL_NUM_SHADER_BINARY_FORMATS},
        {"GL_SHADER_COMPILER", GL_SHADER_COMPILER},
    };
    for (size_t i = 0; i < sizeof integers / sizeof integers[0]; i++) {
        glGetIntegerv(integers[i].pname, &value);
        [REVENANT_LOG appendFormat:@"LIMIT %s %d\n", integers[i].name, (int)value];
    }
    GLint range[2] = {0, 0}, precision = 0;
    glGetShaderPrecisionFormat(GL_FRAGMENT_SHADER, GL_HIGH_FLOAT, range, &precision);
    [REVENANT_LOG appendFormat:@"LIMIT fragment high float range %d %d precision %d\n", range[0], range[1], (int)precision];
    glGetShaderPrecisionFormat(GL_FRAGMENT_SHADER, GL_MEDIUM_FLOAT, range, &precision);
    [REVENANT_LOG appendFormat:@"LIMIT fragment medium float range %d %d precision %d\n", range[0], range[1], (int)precision];
    [REVENANT_LOG appendFormat:@"GL_VERSION %s\nGL_RENDERER %s\nGL_SHADING_LANGUAGE_VERSION %s\nGL_EXTENSIONS %s\n",
        (const char *)glGetString(GL_VERSION), (const char *)glGetString(GL_RENDERER),
        (const char *)glGetString(GL_SHADING_LANGUAGE_VERSION), (const char *)glGetString(GL_EXTENSIONS)];
}

static const char *REVENANT_EXACT_VERTEX =
    "attribute vec2 a_position;\n"
    "attribute float a_x;\n"
    "attribute float a_expected;\n"
    "varying float v_x;\n"
    "varying float v_expected;\n"
    "void main() {\n"
    "    gl_Position = vec4(a_position, 0.0, 1.0);\n"
    "    gl_PointSize = 1.0;\n"
    "    v_x = a_x;\n"
    "    v_expected = a_expected;\n"
    "}\n";

#define REVENANT_EXACT_SIDE 1024
#define REVENANT_EXACT_COUNT (REVENANT_EXACT_SIDE * REVENANT_EXACT_SIDE)
#define REVENANT_EXACT_SETS 3

typedef struct {
    GLfloat position[2];
    GLfloat x;
    GLfloat expected;
} RevenantExactVertex;

// Each set holds integers that a float-to-integer conversion can produce, so each is a float32 value.
// The sets are: every integer from -2^19 up, the integers that straddle 2^24 (the even ones above it), and random
// float truncations with the largest and smallest int32 values in front.
static void revenant_exact_values(int32_t *values, int set)
{
    uint32_t state = 2463534242u;
    for (size_t k = 0; k < REVENANT_EXACT_COUNT; k++) {
        int32_t x = 0;
        if (set == 0) {
            x = (int32_t)k - (1 << 19);
        } else if (set == 1) {
            x = k < (1 << 19) ? (1 << 24) - (1 << 19) + (int32_t)k : (1 << 24) + 2 * ((int32_t)k - (1 << 19));
        } else {
            state ^= state << 13;
            state ^= state >> 17;
            state ^= state << 5;
            float f = (float)state / 4294967296.0f * 2147483648.0f;
            if (f > 2147483520.0f)
                f = 2147483520.0f;
            x = (int32_t)truncf(state & 1 ? -f : f);
        }
        values[k] = x;
    }
    if (set == 2) {
        values[0] = INT32_MIN;
        values[1] = -2147483520;
        values[2] = 2147483520;
    }
}

static void revenant_exact_fill(RevenantExactVertex *vertices, const int32_t *values, NSUInteger *unrepresentable)
{
    for (size_t k = 0; k < REVENANT_EXACT_COUNT; k++) {
        size_t column = k % REVENANT_EXACT_SIDE, row = k / REVENANT_EXACT_SIDE;
        int32_t expected = values[k] & ~((int32_t)2);
        vertices[k].position[0] = ((GLfloat)column + 0.5f) / REVENANT_EXACT_SIDE * 2.0f - 1.0f;
        vertices[k].position[1] = ((GLfloat)row + 0.5f) / REVENANT_EXACT_SIDE * 2.0f - 1.0f;
        vertices[k].x = (GLfloat)values[k];
        vertices[k].expected = (GLfloat)expected;
        if ((int64_t)(GLfloat)values[k] != values[k] || (int64_t)(GLfloat)expected != expected)
            (*unrepresentable)++;
    }
}

// Runs a fragment shader over one point per pixel of a 1024x1024 target, each point carrying its integer and the
// expected value, and counts the pixels the shader marks as equal (green) or not (red).
static void revenant_exact(NSString *name, NSString *fragmentSource)
{
    BOOL fragmentOK = NO, vertexOK = NO, linked = NO;
    NSString *fragmentLog = @"", *vertexLog = @"", *linkLog = @"";
    GLuint fragment = revenant_compile(GL_FRAGMENT_SHADER, fragmentSource, &fragmentOK, &fragmentLog);
    GLuint vertex = revenant_compile(GL_VERTEX_SHADER, [NSString stringWithUTF8String:REVENANT_EXACT_VERTEX], &vertexOK, &vertexLog);
    GLuint program = glCreateProgram();
    glAttachShader(program, vertex);
    glAttachShader(program, fragment);
    if (fragmentOK && vertexOK) {
        glLinkProgram(program);
        GLint status = GL_FALSE;
        glGetProgramiv(program, GL_LINK_STATUS, &status);
        linked = status == GL_TRUE;
        linkLog = revenant_log(program, YES);
    }
    if (!linked) {
        REVENANT_FAILURES++;
        [REVENANT_LOG appendFormat:@"FAIL %@ exact fragment=%@ vertex=%@ link=%@\n", name,
            fragmentOK ? @"ok" : @"fail", vertexOK ? @"ok" : @"fail", revenant_one_line(fragmentLog.length ? fragmentLog : linkLog)];
        revenant_flush();
        glDeleteProgram(program);
        glDeleteShader(fragment);
        glDeleteShader(vertex);
        return;
    }
    GLint aPosition = glGetAttribLocation(program, "a_position");
    GLint aX = glGetAttribLocation(program, "a_x");
    GLint aExpected = glGetAttribLocation(program, "a_expected");

    GLuint texture = 0, framebuffer = 0, buffer = 0;
    glGenTextures(1, &texture);
    glBindTexture(GL_TEXTURE_2D, texture);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, REVENANT_EXACT_SIDE, REVENANT_EXACT_SIDE, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
    glGenFramebuffers(1, &framebuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, framebuffer);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, texture, 0);
    GLenum complete = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    glGenBuffers(1, &buffer);
    glBindBuffer(GL_ARRAY_BUFFER, buffer);
    glViewport(0, 0, REVENANT_EXACT_SIDE, REVENANT_EXACT_SIDE);
    glUseProgram(program);
    glEnableVertexAttribArray((GLuint)aPosition);
    glEnableVertexAttribArray((GLuint)aX);
    glEnableVertexAttribArray((GLuint)aExpected);

    int32_t *values = malloc(sizeof(int32_t) * REVENANT_EXACT_COUNT);
    RevenantExactVertex *vertices = malloc(sizeof(RevenantExactVertex) * REVENANT_EXACT_COUNT);
    GLubyte *pixels = malloc(4 * REVENANT_EXACT_COUNT);
    for (int set = 0; set < REVENANT_EXACT_SETS; set++) {
        NSUInteger unrepresentable = 0, passed = 0, failed = 0, other = 0;
        revenant_exact_values(values, set);
        revenant_exact_fill(vertices, values, &unrepresentable);
        glBufferData(GL_ARRAY_BUFFER, sizeof(RevenantExactVertex) * REVENANT_EXACT_COUNT, vertices, GL_STATIC_DRAW);
        glVertexAttribPointer((GLuint)aPosition, 2, GL_FLOAT, GL_FALSE, sizeof(RevenantExactVertex), (const void *)offsetof(RevenantExactVertex, position));
        glVertexAttribPointer((GLuint)aX, 1, GL_FLOAT, GL_FALSE, sizeof(RevenantExactVertex), (const void *)offsetof(RevenantExactVertex, x));
        glVertexAttribPointer((GLuint)aExpected, 1, GL_FLOAT, GL_FALSE, sizeof(RevenantExactVertex), (const void *)offsetof(RevenantExactVertex, expected));
        glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
        glClear(GL_COLOR_BUFFER_BIT);
        glDrawArrays(GL_POINTS, 0, REVENANT_EXACT_COUNT);
        glReadPixels(0, 0, REVENANT_EXACT_SIDE, REVENANT_EXACT_SIDE, GL_RGBA, GL_UNSIGNED_BYTE, pixels);
        GLenum error = glGetError();
        NSUInteger negative = 0, printed = 0;
        for (size_t k = 0; k < REVENANT_EXACT_COUNT; k++) {
            GLubyte red = pixels[4 * k], green = pixels[4 * k + 1];
            if (green == 255 && red == 0) {
                passed++;
            } else if (red == 255 && green == 0) {
                failed++;
                if (values[k] < 0)
                    negative++;
                if (printed < 8) {
                    [REVENANT_LOG appendFormat:@"  EXACT-FAIL %@ set=%d x=%d expected=%d\n",
                        name, set, (int)values[k], (int)(values[k] & ~((int32_t)2))];
                    printed++;
                }
            } else {
                other++;
            }
        }
        [REVENANT_LOG appendFormat:@"EXACT %@ set=%d points=%d pass=%lu fail=%lu negative=%lu other=%lu unrepresentable=%lu framebuffer=%x glerror=%x\n",
            name, set, REVENANT_EXACT_COUNT, (unsigned long)passed, (unsigned long)failed, (unsigned long)negative,
            (unsigned long)other, (unsigned long)unrepresentable, complete, error];
    }
    free(values);
    free(vertices);
    free(pixels);
    glDeleteBuffers(1, &buffer);
    glDeleteFramebuffers(1, &framebuffer);
    glDeleteTextures(1, &texture);
    glDeleteProgram(program);
    glDeleteShader(fragment);
    glDeleteShader(vertex);
    revenant_flush();
}

// The texture stage runs a translated fragment shader over a render target. The input texture holds a byte pattern
// that the host computes, so each output pixel has one expected value: the texel at the same position, or at half the
// position for map=half. The spec is "out=WxH in=NAME:WxH map=identity|half", or a value map of the list above, and the
// uniforms NAME_size and <output>_size are set from it. A pixel that differs in any channel is a failure, and the first
// failures are logged. identity and half must match exactly; a value map allows one byte.
static const char *REVENANT_TEXTURE_VERTEX =
    "attribute vec2 a_position;\n"
    "void main() {\n"
    "    gl_Position = vec4(a_position, 0.0, 1.0);\n"
    "}\n";

static uint8_t revenant_texel(size_t x, size_t y, size_t channel)
{
    return (uint8_t)(x * 73 + y * 151 + channel * 47);
}

// The value maps check an intrinsic against the host's own computation of it, with a tolerance of one byte because the
// device computes mediump. Each name is the fragment function of intrinsics.metal that it checks, and r8 and rg8 check
// a plane read through a texture of that format. The output is clamped to [0, 1] and rounded to a byte.
static double revenant_unit(size_t x, size_t y, size_t c)
{
    return revenant_texel(x, y, c) / 255.0;
}

static double revenant_clamp(double v)
{
    return v < 0.0 ? 0.0 : v > 1.0 ? 1.0 : v;
}

static void revenant_expect(const char *map, size_t x, size_t y, double out[4])
{
    double v0 = revenant_unit(x, y, 0), v1 = revenant_unit(x, y, 1);
    double v2 = revenant_unit(x, y, 2), v3 = revenant_unit(x, y, 3);
    out[0] = out[1] = out[2] = 0.0;
    out[3] = 1.0;
    if (strcmp(map, "fast_saturate_f32") == 0) {
        out[0] = revenant_clamp(2.0 * v0 - 0.5);
    } else if (strcmp(map, "fast_saturate_v2f32") == 0) {
        out[0] = revenant_clamp(2.0 * v0 - 0.5);
        out[1] = revenant_clamp(2.0 * v1 - 0.5);
    } else if (strcmp(map, "fast_saturate_v3f32") == 0) {
        out[0] = revenant_clamp(2.0 * v0 - 0.5);
        out[1] = revenant_clamp(2.0 * v1 - 0.5);
        out[2] = revenant_clamp(2.0 * v2 - 0.5);
    } else if (strcmp(map, "fabs_v3f16") == 0) {
        out[0] = fabs(v0 - 0.5);
        out[1] = fabs(v1 - 0.5);
        out[2] = fabs(v2 - 0.5);
    } else if (strcmp(map, "dot_v2f16") == 0) {
        out[0] = (v0 * v2 + v1 * v3) * 0.5;
    } else if (strcmp(map, "mix_v2f32") == 0) {
        out[0] = v0 * (1.0 - v3) + v2 * v3;
        out[1] = v1 * (1.0 - v3) + v3 * v3;
    } else if (strcmp(map, "mix_v3f16") == 0) {
        out[0] = v0 * (1.0 - v3) + 0.25 * v3;
        out[1] = v1 * (1.0 - v3) + 0.25 * v3;
        out[2] = v2 * (1.0 - v3) + 0.25 * v3;
    } else if (strcmp(map, "mix_v4f16") == 0) {
        out[0] = (v0 + v3) * 0.5;
        out[1] = (v1 + v2) * 0.5;
        out[2] = (v2 + v1) * 0.5;
        out[3] = (v3 + v0) * 0.5;
    } else if (strcmp(map, "fmin_v3f16") == 0) {
        out[0] = fmin(v0, 0.5);
        out[1] = fmin(v1, 0.5);
        out[2] = fmin(v2, 0.5);
    } else if (strcmp(map, "fmin_f16") == 0) {
        out[0] = fmin(v0, v1);
    } else if (strcmp(map, "tan_f16") == 0 || strcmp(map, "fast_tan_f32") == 0) {
        out[0] = tan(0.7 * v0);
    } else if (strcmp(map, "sqrt_f16") == 0) {
        out[0] = sqrt(v0);
    } else if (strcmp(map, "sqrt_f16_control") == 0) {
        out[0] = 0.5 * sqrt(v0);
    } else if (strcmp(map, "clamp_v3f16") == 0) {
        out[0] = revenant_clamp(v0 < 0.25 ? 0.25 : v0 > 0.75 ? 0.75 : v0);
        out[1] = revenant_clamp(v1 < 0.25 ? 0.25 : v1 > 0.75 ? 0.75 : v1);
        out[2] = revenant_clamp(v2 < 0.25 ? 0.25 : v2 > 0.75 ? 0.75 : v2);
    } else if (strcmp(map, "fast_exp_f32") == 0) {
        out[0] = exp(-3.0 * v0);
    } else if (strcmp(map, "sin_f16") == 0) {
        out[0] = sin(3.0 * v0) * 0.5 + 0.5;
    } else if (strcmp(map, "cos_f16") == 0) {
        out[0] = cos(3.0 * v0) * 0.5 + 0.5;
    } else if (strcmp(map, "fast_floor_f32") == 0) {
        out[0] = floor(4.0 * v0) * 0.25;
    } else if (strcmp(map, "fast_fmax_v3f32") == 0) {
        out[0] = fmax(v0, 0.5);
        out[1] = fmax(v1, 0.5);
        out[2] = fmax(v2, 0.5);
    } else if (strcmp(map, "fast_pow_v3f32") == 0) {
        out[0] = pow(v0, 2.0);
        out[1] = pow(v1, 2.0);
        out[2] = pow(v2, 2.0);
    } else if (strcmp(map, "max_u_i32") == 0) {
        unsigned p = revenant_texel(x, y, 0), q = revenant_texel(x, y, 1);
        out[0] = (double)(p > q ? p : q) / 255.0;
    } else if (strcmp(map, "udiv_u_i32") == 0) {
        unsigned p = revenant_texel(x, y, 0), q = revenant_texel(x, y, 1);
        out[0] = (double)(p / (q > 1 ? q : 1)) / 255.0;
    } else if (strcmp(map, "urem_u_i32") == 0) {
        unsigned p = revenant_texel(x, y, 0), q = revenant_texel(x, y, 1);
        out[0] = (double)(p % (q > 1 ? q : 1)) / 255.0;
    } else if (strcmp(map, "fwidth_f32") == 0) {
        // fwidth of the ramp of intrinsics.metal: 0.75 / 64 per pixel, times 16 in the shader.
        out[0] = 16.0 * 0.75 / 64.0;
    } else if (strcmp(map, "switch_f32") == 0) {
        int branch = (int)floor(3.0 * v0 + 0.5);
        out[0] = branch == 0 ? v1 : branch == 1 ? v2 * 0.5 : branch == 2 ? 1.0 - v3 : 0.25;
    } else if (strcmp(map, "diag") == 0) {
        // Derivatives of the texel value across the quad: the even and odd pixel of a row or column differ by the
        // same signed step, so each pixel's dFdx is the odd minus the even neighbour in its row.
        out[0] = 0.5 + 0.5 * (revenant_unit(x | 1, y, 0) - revenant_unit(x & ~(size_t)1, y, 0));
        out[1] = 0.5 + 0.5 * (revenant_unit(x, y | 1, 0) - revenant_unit(x, y & ~(size_t)1, 0));
    } else if (strcmp(map, "r8") == 0) {
        out[0] = v0;
    } else if (strcmp(map, "rg8") == 0) {
        out[0] = v0;
        out[1] = v1;
    }
}

static BOOL revenant_identity(const char *map)
{
    return strcmp(map, "identity") == 0 || strcmp(map, "half") == 0;
}

// The integer maps are exact: a difference of one in their byte is a wrong quotient or remainder, not rounding.
static BOOL revenant_integer(const char *map)
{
    return strcmp(map, "max_u_i32") == 0 || strcmp(map, "udiv_u_i32") == 0 || strcmp(map, "urem_u_i32") == 0;
}

static int revenant_expected(const char *map, size_t x, size_t y, size_t c)
{
    if (strcmp(map, "half") == 0)
        return revenant_texel(x / 2, y / 2, c);
    if (strcmp(map, "identity") == 0)
        return revenant_texel(x, y, c);
    double out[4];
    revenant_expect(map, x, y, out);
    return (int)lround(255.0 * revenant_clamp(out[c]));
}

static void revenant_texture(NSString *name, NSString *fragmentSource, NSString *spec)
{
    unsigned outW = 0, outH = 0, inW = 0, inH = 0;
    char inName[64] = "", map[32] = "";
    if (sscanf([spec UTF8String], "out=%ux%u in=%63[^:]:%ux%u map=%31s", &outW, &outH, inName, &inW, &inH, map) != 6) {
        REVENANT_FAILURES++;
        [REVENANT_LOG appendFormat:@"FAIL %@ texture bad spec %@\n", name, spec];
        revenant_flush();
        return;
    }
    BOOL fragmentOK = NO, vertexOK = NO, linked = NO;
    NSString *fragmentLog = @"", *vertexLog = @"", *linkLog = @"";
    GLuint fragment = revenant_compile(GL_FRAGMENT_SHADER, fragmentSource, &fragmentOK, &fragmentLog);
    GLuint vertex = revenant_compile(GL_VERTEX_SHADER, [NSString stringWithUTF8String:REVENANT_TEXTURE_VERTEX], &vertexOK, &vertexLog);
    GLuint program = glCreateProgram();
    glAttachShader(program, vertex);
    glAttachShader(program, fragment);
    glLinkProgram(program);
    GLint status = GL_FALSE;
    glGetProgramiv(program, GL_LINK_STATUS, &status);
    linked = status == GL_TRUE;
    linkLog = revenant_log(program, YES);
    if (!fragmentOK || !vertexOK || !linked) {
        REVENANT_FAILURES++;
        [REVENANT_LOG appendFormat:@"FAIL %@ texture fragment=%d vertex=%d link=%d\n", name, fragmentOK, vertexOK, linked];
        if (fragmentLog.length) [REVENANT_LOG appendFormat:@"  fragment log: %@\n", revenant_one_line(fragmentLog)];
        if (linkLog.length) [REVENANT_LOG appendFormat:@"  link log: %@\n", revenant_one_line(linkLog)];
        revenant_flush();
        return;
    }
    glUseProgram(program);

    GLenum format = GL_RGBA;
    size_t channels = 4;
    if (strcmp(map, "r8") == 0) {
        format = GL_RED_EXT;
        channels = 1;
    } else if (strcmp(map, "rg8") == 0) {
        format = GL_RG_EXT;
        channels = 2;
    }
    uint8_t *input = malloc((size_t)inW * inH * channels);
    for (size_t y = 0; y < inH; y++)
        for (size_t x = 0; x < inW; x++)
            for (size_t c = 0; c < channels; c++)
                input[(y * inW + x) * channels + c] = revenant_texel(x, y, c);
    GLuint texture = 0;
    glGenTextures(1, &texture);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, texture);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexImage2D(GL_TEXTURE_2D, 0, format, inW, inH, 0, format, GL_UNSIGNED_BYTE, input);
    free(input);
    GLint location = glGetUniformLocation(program, inName);
    if (location >= 0)
        glUniform1i(location, 0);

    GLint uniformCount = 0;
    glGetProgramiv(program, GL_ACTIVE_UNIFORMS, &uniformCount);
    for (GLint i = 0; i < uniformCount; i++) {
        GLchar uniform[128];
        GLsizei length = 0;
        GLint size = 0;
        GLenum type = 0;
        glGetActiveUniform(program, i, sizeof uniform, &length, &size, &type, uniform);
        size_t count = strlen(uniform);
        if (count <= 5 || strcmp(uniform + count - 5, "_size") != 0)
            continue;
        BOOL isInput = strlen(inName) == count - 5 && strncmp(uniform, inName, count - 5) == 0;
        glUniform2f(glGetUniformLocation(program, uniform), isInput ? inW : outW, isInput ? inH : outH);
    }

    // The render target lives on unit 1, so binding it does not replace the input on unit 0.
    GLuint framebuffer = 0, target = 0;
    glActiveTexture(GL_TEXTURE1);
    glGenTextures(1, &target);
    glBindTexture(GL_TEXTURE_2D, target);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, outW, outH, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
    glGenFramebuffers(1, &framebuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, framebuffer);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, target, 0);
    GLenum complete = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    glActiveTexture(GL_TEXTURE0);
    glViewport(0, 0, outW, outH);
    glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
    glClear(GL_COLOR_BUFFER_BIT);

    static const GLfloat quad[8] = {-1.0f, -1.0f, 1.0f, -1.0f, -1.0f, 1.0f, 1.0f, 1.0f};
    GLint position = glGetAttribLocation(program, "a_position");
    glEnableVertexAttribArray((GLuint)position);
    glVertexAttribPointer((GLuint)position, 2, GL_FLOAT, GL_FALSE, 0, quad);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    glFinish();

    uint8_t *pixels = malloc((size_t)outW * outH * 4);
    glReadPixels(0, 0, outW, outH, GL_RGBA, GL_UNSIGNED_BYTE, pixels);
    GLenum error = glGetError();
    NSUInteger passed = 0, failed = 0;
    int maxDifference = 0;
    for (size_t y = 0; y < outH; y++) {
        for (size_t x = 0; x < outW; x++) {
            int tolerance = revenant_identity(map) || revenant_integer(map) ? 0 : 1;
            BOOL same = YES;
            for (size_t c = 0; c < 4; c++) {
                int got = pixels[(y * outW + x) * 4 + c], expected = revenant_expected(map, x, y, c);
                if (abs(got - expected) > maxDifference)
                    maxDifference = abs(got - expected);
                if (abs(got - expected) > tolerance)
                    same = NO;
            }
            if (same) {
                passed++;
            } else {
                failed++;
                if (failed <= 8) {
                    uint8_t *got = pixels + (y * outW + x) * 4;
                    [REVENANT_LOG appendFormat:@"  TEXTURE-FAIL %@ x=%zu y=%zu got=%d,%d,%d,%d expected=%d,%d,%d,%d\n", name, x, y,
                        got[0], got[1], got[2], got[3], revenant_expected(map, x, y, 0), revenant_expected(map, x, y, 1),
                        revenant_expected(map, x, y, 2), revenant_expected(map, x, y, 3)];
                }
            }
        }
    }
    free(pixels);
    [REVENANT_LOG appendFormat:@"%@ %@ texture map=%s out=%ux%u in=%s:%ux%u pass=%lu fail=%lu maxdiff=%d framebuffer=%x glerror=%x\n",
        failed ? @"FAIL" : @"PASS", name, map, outW, outH, inName, inW, inH, (unsigned long)passed, (unsigned long)failed,
        maxDifference, (unsigned)complete, (unsigned)error];
    if (failed)
        REVENANT_FAILURES++;

    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glDeleteFramebuffers(1, &framebuffer);
    glDeleteTextures(1, &target);
    glDeleteTextures(1, &texture);
    glDeleteProgram(program);
    glDeleteShader(fragment);
    glDeleteShader(vertex);
    revenant_flush();
}

int main(int argc, char *argv[])
{
    @autoreleasepool {
        REVENANT_ROOT = argc > 1 ? [NSString stringWithUTF8String:argv[1]] : @"/var/revenant/es2";
        REVENANT_LOG = [NSMutableString string];
        EAGLContext *context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
        if (!context || ![EAGLContext setCurrentContext:context]) {
            [REVENANT_LOG appendString:@"FAIL no OpenGL ES 2 context\n"];
            revenant_flush();
            printf("%s", [REVENANT_LOG UTF8String]);
            return 1;
        }
        revenant_limits();
        NSString *manifest = [NSString stringWithContentsOfFile:[REVENANT_ROOT stringByAppendingPathComponent:@"manifest.txt"]
                                                       encoding:NSUTF8StringEncoding error:NULL];
        NSUInteger programs = 0;
        for (NSString *line in [manifest componentsSeparatedByString:@"\n"]) {
            NSArray *fields = [line componentsSeparatedByString:@"\t"];
            if (fields.count != 4 || [line hasPrefix:@"#"])
                continue;
            NSString *translated = [NSString stringWithContentsOfFile:fields[2] encoding:NSUTF8StringEncoding error:NULL];
            if ([fields[1] isEqualToString:@"texture"]) {
                programs++;
                if (!translated) {
                    REVENANT_FAILURES++;
                    [REVENANT_LOG appendFormat:@"FAIL %@ unreadable source\n", fields[0]];
                    revenant_flush();
                    continue;
                }
                revenant_texture(fields[0], translated, fields[3]);
                continue;
            }
            if ([fields[1] isEqualToString:@"exact"]) {
                programs++;
                if (!translated) {
                    REVENANT_FAILURES++;
                    [REVENANT_LOG appendFormat:@"FAIL %@ unreadable source\n", fields[0]];
                    revenant_flush();
                    continue;
                }
                revenant_exact(fields[0], translated);
                continue;
            }
            NSString *companion = [NSString stringWithContentsOfFile:fields[3] encoding:NSUTF8StringEncoding error:NULL];
            programs++;
            if (!translated || !companion) {
                REVENANT_FAILURES++;
                [REVENANT_LOG appendFormat:@"FAIL %@ unreadable source\n", fields[0]];
                revenant_flush();
                continue;
            }
            revenant_program(fields[0], fields[1], translated, companion);
        }
        [REVENANT_LOG appendFormat:@"REVENANT-DONE programs %lu failures %lu\n", (unsigned long)programs, (unsigned long)REVENANT_FAILURES];
        revenant_flush();
        printf("%s", [REVENANT_LOG UTF8String]);
        return REVENANT_FAILURES ? 1 : 0;
    }
}
