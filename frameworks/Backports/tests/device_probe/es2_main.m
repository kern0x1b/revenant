#import <Foundation/Foundation.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>

static NSString *const REVENANT_ROOT = @"/var/revenant/es2";
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

int main(int argc, char *argv[])
{
    @autoreleasepool {
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
