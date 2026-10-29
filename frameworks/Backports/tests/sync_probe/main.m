#import <Foundation/Foundation.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>
#import <mach/mach_time.h>
#import <stdio.h>
#import <stdlib.h>
#import <string.h>

#define SIZE 256
#define WORK 50
#define ITERATIONS 300

static mach_timebase_info_data_t timebase;

static double micros(uint64_t ticks)
{
    return (double)ticks * timebase.numer / timebase.denom / 1000.0;
}

static void work(int index)
{
    for (int i = 0; i < WORK; i++) {
        glClearColor((i + index) % 7 / 7.0f, 0.5f, 0.25f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT);
    }
}

static uint64_t finishRound(int index)
{
    uint64_t start = mach_absolute_time();
    work(index);
    glFlush();
    glFinish();
    return mach_absolute_time() - start;
}

static uint64_t fenceRound(int index)
{
    uint64_t start = mach_absolute_time();
    work(index);
    GLsync fence = glFenceSyncAPPLE(GL_SYNC_GPU_COMMANDS_COMPLETE_APPLE, 0);
    glFlush();
    GLenum result = GL_TIMEOUT_EXPIRED_APPLE;
    while (result == GL_TIMEOUT_EXPIRED_APPLE)
        result = glClientWaitSyncAPPLE(fence, GL_SYNC_FLUSH_COMMANDS_BIT_APPLE, 1000000000);
    glDeleteSyncAPPLE(fence);
    if (result == GL_WAIT_FAILED_APPLE)
        printf("fence wait failed\n");
    return mach_absolute_time() - start;
}

static int compare(const void *a, const void *b)
{
    double x = *(const double *)a, y = *(const double *)b;
    return (x > y) - (x < y);
}

static void report(const char *name, double *values, int count)
{
    double total = 0;
    for (int i = 0; i < count; i++)
        total += values[i];
    qsort(values, count, sizeof(double), compare);
    printf("%s median_us=%.1f p90_us=%.1f min_us=%.1f mean_us=%.1f\n", name, values[count / 2],
           values[count * 9 / 10], values[0], total / count);
}

int main(void)
{
    @autoreleasepool {
        mach_timebase_info(&timebase);
        EAGLContext *context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
        if (![EAGLContext setCurrentContext:context]) {
            printf("no current context\n");
            return 2;
        }
        const char *extensions = (const char *)glGetString(GL_EXTENSIONS);
        if (!extensions || !strstr(extensions, "GL_APPLE_sync")) {
            printf("GL_APPLE_sync is missing\n");
            return 3;
        }
        GLuint texture = 0;
        glGenTextures(1, &texture);
        glBindTexture(GL_TEXTURE_2D, texture);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, SIZE, SIZE, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
        GLuint framebuffer = 0;
        glGenFramebuffers(1, &framebuffer);
        glBindFramebuffer(GL_FRAMEBUFFER, framebuffer);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, texture, 0);
        printf("framebuffer status=0x%x\n", glCheckFramebufferStatus(GL_FRAMEBUFFER));
        glViewport(0, 0, SIZE, SIZE);

        for (int i = 0; i < 20; i++) {
            finishRound(i);
            fenceRound(i);
        }

        static double finish[ITERATIONS], fence[ITERATIONS];
        for (int i = 0; i < ITERATIONS; i++) {
            if (i % 2) {
                finish[i] = micros(finishRound(i));
                fence[i] = micros(fenceRound(i));
            } else {
                fence[i] = micros(fenceRound(i));
                finish[i] = micros(finishRound(i));
            }
        }
        report("glFinish", finish, ITERATIONS);
        report("flush+fence", fence, ITERATIONS);
        printf("glError=0x%x\n", glGetError());
        [EAGLContext setCurrentContext:nil];
    }
    return 0;
}
