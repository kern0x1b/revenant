// gl-extensions : what the GPU's OpenGL ES 2.0 context offers — its renderer, version and extensions, one per line. The SCNView renderer picks how it holds a colour slot's image from this (facts/SceneKit/SCNView.md, "Textures").
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES2/gl.h>
#include <stdio.h>
#include <string.h>

int main(void)
{
    @autoreleasepool {
        EAGLContext *context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
        if (context == nil || ![EAGLContext setCurrentContext:context]) {
            printf("FAIL no OpenGL ES 2.0 context\n");
            return 1;
        }
        printf("renderer %s\nversion %s\n", glGetString(GL_RENDERER), glGetString(GL_VERSION));
        char *all = strdup((const char *)glGetString(GL_EXTENSIONS));
        for (char *e = strtok(all, " "); e; e = strtok(NULL, " ")) printf("extension %s\n", e);
        free(all);
    }
    return 0;
}
