#import <UIKit/UIKit.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES2/gl.h>
#include <stdio.h>

static CFAbsoluteTime REVENANT_START;
static char REVENANT_VARIANT = '0';
static EAGLContext *REVENANT_CONTEXT;
static GLuint REVENANT_PROGRAM;
static GLuint REVENANT_FRAMEBUFFER;

static void revenant_event(NSString *text)
{
    printf("t=%.2f %s\n", CFAbsoluteTimeGetCurrent() - REVENANT_START, [text UTF8String]);
    fflush(stdout);
}

static void revenant_check(const char *what)
{
    revenant_event([NSString stringWithFormat:@"%s glError=0x%x", what, glGetError()]);
}

static GLuint revenant_shader(GLenum type, const char *source)
{
    GLuint shader = glCreateShader(type);
    glShaderSource(shader, 1, &source, NULL);
    glCompileShader(shader);
    GLint ok = 0;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &ok);
    revenant_event([NSString stringWithFormat:@"compile type=0x%x ok=%d", type, ok]);
    return shader;
}

static void revenant_build_program(void)
{
    GLuint vertex = revenant_shader(GL_VERTEX_SHADER, "attribute vec2 p; void main() { gl_Position = vec4(p, 0.0, 1.0); }");
    GLuint fragment = revenant_shader(GL_FRAGMENT_SHADER, "precision mediump float; void main() { gl_FragColor = vec4(1.0, 0.5, 0.25, 1.0); }");
    REVENANT_PROGRAM = glCreateProgram();
    glAttachShader(REVENANT_PROGRAM, vertex);
    glAttachShader(REVENANT_PROGRAM, fragment);
    glBindAttribLocation(REVENANT_PROGRAM, 0, "p");
    glLinkProgram(REVENANT_PROGRAM);
    GLint linked = 0;
    glGetProgramiv(REVENANT_PROGRAM, GL_LINK_STATUS, &linked);
    revenant_event([NSString stringWithFormat:@"link ok=%d", linked]);
    glDeleteShader(vertex);
    glDeleteShader(fragment);
}

static void revenant_draw(void)
{
    glGenFramebuffers(1, &REVENANT_FRAMEBUFFER);
    glBindFramebuffer(GL_FRAMEBUFFER, REVENANT_FRAMEBUFFER);
    GLuint renderbuffer = 0;
    glGenRenderbuffers(1, &renderbuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, renderbuffer);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_RGBA4, 16, 16);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, renderbuffer);
    glViewport(0, 0, 16, 16);
    glUseProgram(REVENANT_PROGRAM);
    static const GLfloat triangle[6] = {-1.0f, -1.0f, 1.0f, -1.0f, 0.0f, 1.0f};
    GLuint buffer = 0;
    glGenBuffers(1, &buffer);
    glBindBuffer(GL_ARRAY_BUFFER, buffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(triangle), triangle, GL_STATIC_DRAW);
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 0, 0);
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);
    glDrawArrays(GL_TRIANGLES, 0, 3);
    glFinish();
    revenant_check("draw");
}

static void revenant_make_context(void)
{
    REVENANT_CONTEXT = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    revenant_event([NSString stringWithFormat:@"context created=%d", REVENANT_CONTEXT != nil]);
}

static void revenant_retire_context(void)
{
    [EAGLContext setCurrentContext:REVENANT_CONTEXT];
    glFinish();
    [EAGLContext setCurrentContext:nil];
    REVENANT_CONTEXT = nil;
    revenant_event(@"context destroyed");
}

@interface RevenantGLLockView : UIView
@end

@implementation RevenantGLLockView
@end

@interface RevenantGLLockProbe : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation RevenantGLLockProbe

- (void)runVariant
{
    char variant = REVENANT_VARIANT;
    if (variant == '0')
        return;
    if (variant == '4') {
        revenant_make_context();
        return;
    }
    revenant_make_context();
    [EAGLContext setCurrentContext:REVENANT_CONTEXT];
    if (variant == '1') {
        glClearColor(0.5f, 0.5f, 0.5f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT);
        glFinish();
        revenant_check("clear");
    } else if (variant == '5') {
        revenant_build_program();
    } else {
        revenant_build_program();
        revenant_draw();
    }
    if (variant != '6')
        [EAGLContext setCurrentContext:nil];
    if (variant == '7')
        revenant_retire_context();
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    REVENANT_START = CFAbsoluteTimeGetCurrent();
    FILE *file = fopen("/var/revenant/gl-variant", "r");
    if (file) {
        int c = fgetc(file);
        if (c != EOF)
            REVENANT_VARIANT = (char)c;
        fclose(file);
    }
    revenant_event([NSString stringWithFormat:@"launched variant=%c applicationState=%ld", REVENANT_VARIANT, (long)application.applicationState]);
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    UIViewController *controller = [[UIViewController alloc] init];
    controller.view = [[RevenantGLLockView alloc] initWithFrame:self.window.bounds];
    self.window.rootViewController = controller;
    [self.window makeKeyAndVisible];
    [self runVariant];
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserverForName:UIApplicationDidEnterBackgroundNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        revenant_event(@"DidEnterBackground");
        if ((REVENANT_VARIANT == '3' || REVENANT_VARIANT == '8') && REVENANT_CONTEXT)
            revenant_retire_context();
    }];
    [center addObserverForName:UIApplicationWillEnterForegroundNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        revenant_event(@"WillEnterForeground");
        if (REVENANT_VARIANT == '8') {
            revenant_make_context();
            [EAGLContext setCurrentContext:REVENANT_CONTEXT];
            revenant_build_program();
            revenant_draw();
            [EAGLContext setCurrentContext:nil];
        }
    }];
    revenant_event(@"ready");
    return YES;
}

@end

int main(int argc, char *argv[])
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([RevenantGLLockProbe class]));
    }
}
