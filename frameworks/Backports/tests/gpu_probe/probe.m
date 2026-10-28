#import <Foundation/Foundation.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES2/gl.h>
#include <stdio.h>
#include <string.h>

static const char *str(const GLubyte *s) {
    return s ? (const char *)s : "(null)";
}

int main(int argc, char **argv) {
    @autoreleasepool {
        EAGLContext *ctx = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
        printf("context=%p api=%d\n", (void *)ctx, (int)ctx.API);
        if (!ctx) return 2;
        BOOL current = [EAGLContext setCurrentContext:ctx];
        printf("setCurrent=%d\n", (int)current);
        printf("GL_VENDOR=%s\n", str(glGetString(GL_VENDOR)));
        printf("GL_RENDERER=%s\n", str(glGetString(GL_RENDERER)));
        printf("GL_VERSION=%s\n", str(glGetString(GL_VERSION)));
        GLint maxTex = 0;
        glGetIntegerv(GL_MAX_TEXTURE_SIZE, &maxTex);
        printf("GL_MAX_TEXTURE_SIZE=%d\n", (int)maxTex);
        glFinish();
        printf("glError=0x%x\n", (unsigned)glGetError());
        [EAGLContext setCurrentContext:nil];
        printf("done\n");
    }
    return 0;
}
