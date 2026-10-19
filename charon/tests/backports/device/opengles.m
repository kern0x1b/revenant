#import <UIKit/UIKit.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>
#include <dlfcn.h>
#import "check.h"

static NSString *const results_folder = @"/private/var/backports";

extern void glBindVertexArray(GLuint);
extern void glGenVertexArrays(GLsizei, GLuint *);
extern void glDeleteVertexArrays(GLsizei, const GLuint *);
extern GLboolean glIsVertexArray(GLuint);
extern void glGenQueries(GLsizei, GLuint *);
extern void glBeginQuery(GLenum, GLuint);
extern void glEndQuery(GLenum);
extern void glGetQueryObjectuiv(GLuint, GLenum, GLuint *);
extern void glDeleteQueries(GLsizei, const GLuint *);
extern GLboolean glIsQuery(GLuint);
extern struct __GLsync *glFenceSync(GLenum, GLbitfield);
extern GLenum glClientWaitSync(struct __GLsync *, GLbitfield, unsigned long long);
extern GLboolean glIsSync(struct __GLsync *);
extern void glDeleteSync(struct __GLsync *);
extern void *glMapBufferRange(GLenum, GLintptr, GLsizeiptr, GLbitfield);
extern void glFlushMappedBufferRange(GLenum, GLintptr, GLsizeiptr);
extern const GLubyte *glGetStringi(GLenum, GLuint);
extern void glBlitFramebuffer(GLint, GLint, GLint, GLint, GLint, GLint, GLint, GLint, GLbitfield, GLenum);
extern void glTexStorage2D(GLenum, GLsizei, GLenum, GLsizei, GLsizei);
extern void glInvalidateFramebuffer(GLenum, GLsizei, const GLenum *);
extern void glRenderbufferStorageMultisample(GLenum, GLsizei, GLenum, GLsizei, GLsizei);
extern void glUniform1ui(GLint, GLuint);
extern GLuint glGetUniformBlockIndex(GLuint, const GLchar *);
extern GLboolean glUnmapBuffer(GLenum);

static GLuint program(void)
{
    const char *vertex = "attribute vec2 p; void main() { gl_Position = vec4(p, 0.0, 1.0); }";
    const char *fragment = "precision mediump float; void main() { gl_FragColor = vec4(1.0); }";
    GLuint v = glCreateShader(GL_VERTEX_SHADER), f = glCreateShader(GL_FRAGMENT_SHADER), p = glCreateProgram();
    glShaderSource(v, 1, &vertex, NULL);
    glCompileShader(v);
    glShaderSource(f, 1, &fragment, NULL);
    glCompileShader(f);
    glAttachShader(p, v);
    glAttachShader(p, f);
    glBindAttribLocation(p, 0, "p");
    glLinkProgram(p);
    return p;
}

@interface GLDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation GLDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    [[NSFileManager defaultManager] createDirectoryAtPath:results_folder withIntermediateDirectories:YES attributes:nil error:NULL];
    [[NSFileManager defaultManager] removeItemAtPath:[results_folder stringByAppendingPathComponent:@"opengles.done"] error:NULL];
    charon_log_to([results_folder stringByAppendingPathComponent:@"opengles.log"]);
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = [[UIViewController alloc] init];
    [self.window makeKeyAndVisible];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self run];
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
        NSString *summary = [NSString stringWithFormat:@"%@ checks=%d failures=%d\n", charon_failures ? @"FAIL" : @"ok", charon_checks, charon_failures];
        [summary writeToFile:[results_folder stringByAppendingPathComponent:@"opengles.done"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    });
    return YES;
}

- (void)run
{
    CHECK([[EAGLContext alloc] initWithAPI:(EAGLRenderingAPI)3] == nil, "the release makes no ES 3.0 context, so an application that asks first falls back");
    EAGLContext *context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    CHECK(context && [EAGLContext setCurrentContext:context], "an ES 2.0 context");
    const char *names[] = {"glReadBuffer", "glTexImage3D", "glGenQueries", "glBeginQuery", "glDrawBuffers", "glBlitFramebuffer", "glMapBufferRange", "glBindVertexArray", "glGenVertexArrays", "glBeginTransformFeedback",
                           "glVertexAttribIPointer", "glGetStringi", "glUniform1ui", "glFenceSync", "glGenSamplers", "glDrawElementsInstanced", "glProgramParameteri", "glInvalidateFramebuffer", "glTexStorage2D", "glGetInteger64v"};
    BOOL all = YES;
    for (size_t index = 0; index < sizeof names / sizeof names[0]; index++)
        all = all && dlsym(RTLD_DEFAULT, names[index]) != NULL;
    CHECK(all, "the functions of ES 3.0 are there to link against");

    GLuint array = 0;
    glGenVertexArrays(1, &array);
    glBindVertexArray(array);
    CHECK(array != 0 && glIsVertexArray(array) && glGetError() == GL_NO_ERROR, "a vertex array object is made and bound");
    glBindVertexArray(0);
    glDeleteVertexArrays(1, &array);
    CHECK(!glIsVertexArray(array), "and deleted");

    GLuint framebuffer, renderbuffer;
    glGenFramebuffers(1, &framebuffer);
    glGenRenderbuffers(1, &renderbuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, framebuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, renderbuffer);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_RGBA4, 64, 64);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, renderbuffer);
    CHECK(glCheckFramebufferStatus(GL_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE, "a framebuffer to draw in");
    glViewport(0, 0, 64, 64);
    GLuint used = program();
    glUseProgram(used);
    GLfloat triangle[] = {-1, -1, 3, -1, -1, 3};
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 0, triangle);

    GLuint query = 0;
    glGenQueries(1, &query);
    glBeginQuery(0x8C2F, query);
    glDrawArrays(GL_TRIANGLES, 0, 3);
    glEndQuery(0x8C2F);
    GLuint available = 0, result = 9;
    for (int spin = 0; spin < 100 && !available; spin++)
        glGetQueryObjectuiv(query, 0x8867, &available);
    glGetQueryObjectuiv(query, 0x8866, &result);
    CHECK(glIsQuery(query) && available && result == 1 && glGetError() == GL_NO_ERROR, "an occlusion query says the triangle drew");
    glDeleteQueries(1, &query);

    struct __GLsync *fence = glFenceSync(0x9117, 0);
    GLenum waited = glClientWaitSync(fence, 1, 1000000000ull);
    CHECK(fence && glIsSync(fence) && (waited == 0x911A || waited == 0x911C), "a fence sync signals");
    glDeleteSync(fence);
    CHECK(glGetError() == GL_NO_ERROR, "and is deleted");

    GLuint buffer;
    glGenBuffers(1, &buffer);
    glBindBuffer(GL_ARRAY_BUFFER, buffer);
    glBufferData(GL_ARRAY_BUFFER, 64, NULL, GL_DYNAMIC_DRAW);
    uint8_t *mapped = glMapBufferRange(GL_ARRAY_BUFFER, 8, 32, 0x0002 | 0x0010 | 0x0004);
    BOOL wrote = mapped != NULL;
    for (int index = 0; wrote && index < 32; index++)
        mapped[index] = (uint8_t)(index + 1);
    if (mapped)
        glFlushMappedBufferRange(GL_ARRAY_BUFFER, 0, 32);
    BOOL unmapped = glUnmapBuffer(GL_ARRAY_BUFFER);
    const uint8_t *back = glMapBufferRange(GL_ARRAY_BUFFER, 8, 32, 0x0001);
    CHECK(wrote && unmapped && back && back[0] == 1 && back[31] == 32 && glGetError() == GL_NO_ERROR, "a range of a buffer is mapped, written, flushed and read back");
    glUnmapBuffer(GL_ARRAY_BUFFER);

    const char *extensions = (const char *)glGetString(GL_EXTENSIONS);
    const GLubyte *first = glGetStringi(GL_EXTENSIONS, 0);
    size_t length = strcspn(extensions, " ");
    CHECK(first && strlen((const char *)first) == length && !strncmp((const char *)first, extensions, length), "the first extension name is the first of the extension string");
    CHECK(glGetStringi(GL_EXTENSIONS, 100000) == NULL && glGetError() == GL_INVALID_VALUE, "an index past them is a value error");
    glGetError();

    GLenum attachment = GL_COLOR_ATTACHMENT0;
    glInvalidateFramebuffer(GL_FRAMEBUFFER, 1, &attachment);
    CHECK(glGetError() == GL_NO_ERROR, "a framebuffer is invalidated as it is discarded");
    GLuint multisampled;
    glGenRenderbuffers(1, &multisampled);
    glBindRenderbuffer(GL_RENDERBUFFER, multisampled);
    glRenderbufferStorageMultisample(GL_RENDERBUFFER, 4, GL_RGBA4, 32, 32);
    GLint samples = 0;
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, 0x8CAB, &samples);
    CHECK(glGetError() == GL_NO_ERROR && samples >= 1, "a multisampled renderbuffer keeps its samples");
    GLuint texture;
    glGenTextures(1, &texture);
    glBindTexture(GL_TEXTURE_2D, texture);
    glTexStorage2D(GL_TEXTURE_2D, 3, 0x8058, 16, 16);
    BOOL stored = glGetError() == GL_NO_ERROR;
    glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, 16, 16, GL_RGBA, GL_UNSIGNED_BYTE, calloc(16 * 16, 4));
    CHECK(stored && glGetError() == GL_NO_ERROR, "an immutable texture is stored and filled");

    glBlitFramebuffer(0, 0, 8, 8, 0, 0, 8, 8, GL_COLOR_BUFFER_BIT, GL_NEAREST);
    CHECK(glGetError() == GL_INVALID_ENUM, "a call with no answer in ES 2.0 sets an error and does nothing");
    glUniform1ui(0, 1);
    GLuint block = glGetUniformBlockIndex(used, "b");
    CHECK(block == 0 && glGetError() == GL_INVALID_ENUM, "and answers zero");
    [EAGLContext setCurrentContext:nil];
}

@end

int main(int argc, char **argv)
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([GLDelegate class]));
    }
}
