#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>
#include <stdlib.h>
#include <string.h>

// Feasibility of the CoreVideo texture cache on the device: NV12 planes bound as GL_RED_EXT and GL_RG_EXT through
// CVOpenGLESTextureCache, a BGRA buffer sampled after a CPU write, and a BGRA buffer written by the GPU and read by
// the CPU. Each comparison is exact, and each has a negative control that must fail. Only system APIs are used.

static const size_t kSize = 64;
static NSMutableString *LOG;
static NSUInteger FAILURES;

static uint8_t yAt(size_t x, size_t y) { return (uint8_t)(x * 7 + y * 13); }
static uint8_t cbAt(size_t x, size_t y) { return (uint8_t)(x * 5 + y * 3 + 9); }
static uint8_t crAt(size_t x, size_t y) { return (uint8_t)(x * 11 + y * 17 + 40); }
// The GPU-written pattern of the output test, as the shader computes it.
static uint8_t outR(size_t x, size_t y) { return (uint8_t)((x * 3 + y * 5) % 256); }
static uint8_t outG(size_t x, size_t y) { return (uint8_t)((x * 7 + y * 2 + 11) % 256); }
static uint8_t outB(size_t x, size_t y) { return (uint8_t)((x * 2 + y * 9 + 23) % 256); }

static const char *kVertex =
    "attribute vec2 a_position;\n"
    "void main() {\n"
    "    gl_Position = vec4(a_position, 0.0, 1.0);\n"
    "}\n";

static const char *kSample =
    "precision highp float;\n"
    "uniform sampler2D tex;\n"
    "uniform vec2 size;\n"
    "void main() {\n"
    "    gl_FragColor = texture2D(tex, gl_FragCoord.xy / size);\n"
    "}\n";

static const char *kWrite =
    "precision highp float;\n"
    "void main() {\n"
    "    float x = floor(gl_FragCoord.x);\n"
    "    float y = floor(gl_FragCoord.y);\n"
    "    gl_FragColor = vec4(mod(x * 3.0 + y * 5.0, 256.0) + 0.25, mod(x * 7.0 + y * 2.0 + 11.0, 256.0) + 0.25,\n"
    "                        mod(x * 2.0 + y * 9.0 + 23.0, 256.0) + 0.25, 255.25) / 255.0;\n"
    "}\n";

static GLuint compile(GLenum type, const char *source)
{
    GLuint shader = glCreateShader(type);
    glShaderSource(shader, 1, &source, NULL);
    glCompileShader(shader);
    GLint ok = GL_FALSE;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &ok);
    if (ok != GL_TRUE) {
        GLchar log[512] = "";
        glGetShaderInfoLog(shader, sizeof log, NULL, log);
        [LOG appendFormat:@"  shader compile failed: %s\n", log];
        return 0;
    }
    return shader;
}

static GLuint program(const char *fragment)
{
    GLuint vertex = compile(GL_VERTEX_SHADER, kVertex);
    GLuint fragmentShader = compile(GL_FRAGMENT_SHADER, fragment);
    GLuint result = glCreateProgram();
    glAttachShader(result, vertex);
    glAttachShader(result, fragmentShader);
    glBindAttribLocation(result, 0, "a_position");
    glLinkProgram(result);
    GLint ok = GL_FALSE;
    glGetProgramiv(result, GL_LINK_STATUS, &ok);
    if (ok != GL_TRUE) {
        [LOG appendString:@"  program link failed\n"];
        return 0;
    }
    return result;
}

// Draws the full target through the program, sampling unit 0 (the source texture) at each texel centre.
static GLuint draw(GLuint shader, GLuint source, size_t w, size_t h, GLuint target)
{
    GLuint framebuffer = 0;
    glGenFramebuffers(1, &framebuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, framebuffer);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, target, 0);
    glViewport(0, 0, (GLsizei)w, (GLsizei)h);
    glUseProgram(shader);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, source);
    glUniform1i(glGetUniformLocation(shader, "tex"), 0);
    glUniform2f(glGetUniformLocation(shader, "size"), (GLfloat)w, (GLfloat)h);
    static const GLfloat quad[8] = {-1.0f, -1.0f, 1.0f, -1.0f, -1.0f, 1.0f, 1.0f, 1.0f};
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 0, quad);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    glFinish();
    return framebuffer;
}

static GLuint newTarget(size_t w, size_t h)
{
    GLuint texture = 0;
    glGenTextures(1, &texture);
    glBindTexture(GL_TEXTURE_2D, texture);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, (GLsizei)w, (GLsizei)h, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
    return texture;
}

// Counts the bytes of got that differ from expected in the channels of mask (bit 0 red .. bit 3 alpha).
static NSUInteger differences(const uint8_t *got, const uint8_t *expected, size_t count, unsigned mask, int *largest)
{
    NSUInteger bad = 0;
    *largest = 0;
    for (size_t i = 0; i < count; i++) {
        for (size_t c = 0; c < 4; c++) {
            if (!(mask & (1u << c)))
                continue;
            int delta = abs((int)got[i * 4 + c] - (int)expected[i * 4 + c]);
            if (delta > *largest)
                *largest = delta;
            if (delta != 0)
                bad++;
        }
    }
    return bad;
}

static void report(NSString *name, NSUInteger bad, int largest, BOOL negativeControl)
{
    BOOL passed = negativeControl ? bad > 0 : bad == 0;
    if (!passed)
        FAILURES++;
    [LOG appendFormat:@"%@ %@ bad=%lu largest=%d%s\n", passed ? @"PASS" : @"FAIL", name, (unsigned long)bad, largest,
        negativeControl ? " (negative control: must differ)" : ""];
}

// Samples a CoreVideo texture of one plane into an RGBA target, and reads the target back.
static BOOL sampleBuffer(CVOpenGLESTextureCacheRef cache, CVPixelBufferRef buffer, size_t plane, GLint internal,
    GLenum format, size_t w, size_t h, GLuint shader, uint8_t *got, NSString *name)
{
    CVOpenGLESTextureRef texture = NULL;
    CVReturn status = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, cache, buffer, NULL,
        GL_TEXTURE_2D, internal, (GLsizei)w, (GLsizei)h, format, GL_UNSIGNED_BYTE, plane, &texture);
    if (status != kCVReturnSuccess || !texture) {
        [LOG appendFormat:@"FAIL %@ CVOpenGLESTextureCacheCreateTextureFromImage status %d\n", name, (int)status];
        FAILURES++;
        return NO;
    }
    glBindTexture(CVOpenGLESTextureGetTarget(texture), CVOpenGLESTextureGetName(texture));
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    GLuint target = newTarget(w, h);
    GLuint framebuffer = draw(shader, CVOpenGLESTextureGetName(texture), w, h, target);
    glReadPixels(0, 0, (GLsizei)w, (GLsizei)h, GL_RGBA, GL_UNSIGNED_BYTE, got);
    GLenum error = glGetError();
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glDeleteFramebuffers(1, &framebuffer);
    glDeleteTextures(1, &target);
    CFRelease(texture);
    CVOpenGLESTextureCacheFlush(cache, 0);
    if (error != GL_NO_ERROR) {
        [LOG appendFormat:@"FAIL %@ glerror=0x%x\n", name, (unsigned)error];
        FAILURES++;
    }
    return error == GL_NO_ERROR;
}

static CVPixelBufferRef newBuffer(OSType format, size_t size)
{
    NSDictionary *attributes = @{ (__bridge NSString *)kCVPixelBufferIOSurfacePropertiesKey: @{} };
    CVPixelBufferRef buffer = NULL;
    CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault, size, size, format,
        (__bridge CFDictionaryRef)attributes, &buffer);
    if (status != kCVReturnSuccess) {
        [LOG appendFormat:@"CVPixelBufferCreate %u status %d\n", (unsigned)format, (int)status];
        return NULL;
    }
    [LOG appendFormat:@"buffer %u %zux%zu iosurface=%d\n", (unsigned)format, size, size,
        CVPixelBufferGetIOSurface(buffer) != NULL];
    return buffer;
}

int main(int argc, char *argv[])
{
    @autoreleasepool {
        LOG = [NSMutableString string];
        EAGLContext *context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
        if (!context || ![EAGLContext setCurrentContext:context]) {
            printf("FAIL no OpenGL ES 2 context\n");
            return 1;
        }
        CVOpenGLESTextureCacheRef cache = NULL;
        CVReturn status = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, context, NULL, &cache);
        [LOG appendFormat:@"cache status %d\n", (int)status];
        if (status != kCVReturnSuccess || !cache) {
            printf("%s", [LOG UTF8String]);
            return 1;
        }
        GLuint sample = program(kSample);
        GLuint write = program(kWrite);

        // NV12: CPU writes the planes, the GPU samples them as R8 and RG8.
        CVPixelBufferRef nv12 = newBuffer(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, kSize);
        if (nv12) {
            CVPixelBufferLockBaseAddress(nv12, 0);
            uint8_t *luma = CVPixelBufferGetBaseAddressOfPlane(nv12, 0);
            size_t lumaStride = CVPixelBufferGetBytesPerRowOfPlane(nv12, 0);
            for (size_t y = 0; y < kSize; y++)
                for (size_t x = 0; x < kSize; x++)
                    luma[y * lumaStride + x] = yAt(x, y);
            uint8_t *chroma = CVPixelBufferGetBaseAddressOfPlane(nv12, 1);
            size_t chromaStride = CVPixelBufferGetBytesPerRowOfPlane(nv12, 1);
            size_t half = kSize / 2;
            for (size_t y = 0; y < half; y++)
                for (size_t x = 0; x < half; x++) {
                    chroma[y * chromaStride + 2 * x] = cbAt(x, y);
                    chroma[y * chromaStride + 2 * x + 1] = crAt(x, y);
                }
            CVPixelBufferUnlockBaseAddress(nv12, 0);

            uint8_t *got = malloc(kSize * kSize * 4), *expected = malloc(kSize * kSize * 4);
            int largest = 0;
            if (sampleBuffer(cache, nv12, 0, GL_RED_EXT, GL_RED_EXT, kSize, kSize, sample, got, @"nv12 luma")) {
                for (size_t y = 0; y < kSize; y++)
                    for (size_t x = 0; x < kSize; x++) {
                        uint8_t *e = expected + (y * kSize + x) * 4;
                        e[0] = yAt(x, y); e[1] = 0; e[2] = 0; e[3] = 255;
                    }
                report(@"nv12 luma as R8, red channel", differences(got, expected, kSize * kSize, 0x1, &largest), largest, NO);
                // Negative control: the chroma values must not match the luma plane.
                for (size_t y = 0; y < kSize; y++)
                    for (size_t x = 0; x < kSize; x++) {
                        uint8_t *e = expected + (y * kSize + x) * 4;
                        e[0] = cbAt(x / 2, y / 2); e[1] = 0; e[2] = 0; e[3] = 255;
                    }
                report(@"nv12 luma against chroma (negative control)", differences(got, expected, kSize * kSize, 0x1, &largest), largest, YES);
            }
            size_t half2 = kSize / 2;
            if (sampleBuffer(cache, nv12, 1, GL_RG_EXT, GL_RG_EXT, half2, half2, sample, got, @"nv12 chroma")) {
                for (size_t y = 0; y < half2; y++)
                    for (size_t x = 0; x < half2; x++) {
                        uint8_t *e = expected + (y * half2 + x) * 4;
                        e[0] = cbAt(x, y); e[1] = crAt(x, y); e[2] = 0; e[3] = 255;
                    }
                report(@"nv12 chroma as RG8, red and green", differences(got, expected, half2 * half2, 0x3, &largest), largest, NO);
                // Negative control: the green channel must not be the red channel.
                for (size_t y = 0; y < half2; y++)
                    for (size_t x = 0; x < half2; x++) {
                        uint8_t *e = expected + (y * half2 + x) * 4;
                        e[0] = cbAt(x, y); e[1] = cbAt(x, y); e[2] = 0; e[3] = 255;
                    }
                report(@"nv12 chroma green against red (negative control)", differences(got, expected, half2 * half2, 0x2, &largest), largest, YES);
            }
            free(got);
            free(expected);
            CVPixelBufferRelease(nv12);
        }

        // BGRA written by the CPU, sampled by the GPU: the texel is in RGBA order.
        CVPixelBufferRef bgraIn = newBuffer(kCVPixelFormatType_32BGRA, kSize);
        if (bgraIn) {
            CVPixelBufferLockBaseAddress(bgraIn, 0);
            uint8_t *base = CVPixelBufferGetBaseAddress(bgraIn);
            size_t stride = CVPixelBufferGetBytesPerRow(bgraIn);
            for (size_t y = 0; y < kSize; y++)
                for (size_t x = 0; x < kSize; x++) {
                    uint8_t *p = base + y * stride + x * 4;
                    p[0] = outB(x, y); p[1] = outG(x, y); p[2] = outR(x, y); p[3] = 255;
                }
            CVPixelBufferUnlockBaseAddress(bgraIn, 0);
            uint8_t *got = malloc(kSize * kSize * 4), *expected = malloc(kSize * kSize * 4);
            int largest = 0;
            if (sampleBuffer(cache, bgraIn, 0, GL_RGBA, GL_BGRA_EXT, kSize, kSize, sample, got, @"bgra input")) {
                for (size_t y = 0; y < kSize; y++)
                    for (size_t x = 0; x < kSize; x++) {
                        uint8_t *e = expected + (y * kSize + x) * 4;
                        e[0] = outR(x, y); e[1] = outG(x, y); e[2] = outB(x, y); e[3] = 255;
                    }
                report(@"bgra input sampled as RGBA", differences(got, expected, kSize * kSize, 0xf, &largest), largest, NO);
                for (size_t y = 0; y < kSize; y++)
                    for (size_t x = 0; x < kSize; x++) {
                        uint8_t *e = expected + (y * kSize + x) * 4;
                        e[0] = outB(x, y); e[1] = outG(x, y); e[2] = outR(x, y); e[3] = 255;
                    }
                report(@"bgra input with red and blue swapped (negative control)", differences(got, expected, kSize * kSize, 0xf, &largest), largest, YES);
            }
            free(got);
            free(expected);
            CVPixelBufferRelease(bgraIn);
        }

        // BGRA written by the GPU through a texture of the buffer, read by the CPU: the output path.
        CVPixelBufferRef bgraOut = newBuffer(kCVPixelFormatType_32BGRA, kSize);
        if (bgraOut) {
            CVOpenGLESTextureRef texture = NULL;
            status = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, cache, bgraOut, NULL,
                GL_TEXTURE_2D, GL_RGBA, (GLsizei)kSize, (GLsizei)kSize, GL_BGRA_EXT, GL_UNSIGNED_BYTE, 0, &texture);
            if (status != kCVReturnSuccess || !texture) {
                [LOG appendFormat:@"FAIL bgra output CVOpenGLESTextureCacheCreateTextureFromImage status %d\n", (int)status];
                FAILURES++;
            } else {
                GLuint target = CVOpenGLESTextureGetName(texture);
                glBindTexture(GL_TEXTURE_2D, target);
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
                GLuint framebuffer = 0;
                glGenFramebuffers(1, &framebuffer);
                glBindFramebuffer(GL_FRAMEBUFFER, framebuffer);
                glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, target, 0);
                glViewport(0, 0, (GLsizei)kSize, (GLsizei)kSize);
                glUseProgram(write);
                static const GLfloat quad[8] = {-1.0f, -1.0f, 1.0f, -1.0f, -1.0f, 1.0f, 1.0f, 1.0f};
                glEnableVertexAttribArray(0);
                glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 0, quad);
                glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
                glFinish();
                glBindFramebuffer(GL_FRAMEBUFFER, 0);
                glDeleteFramebuffers(1, &framebuffer);
                CFRelease(texture);
                CVOpenGLESTextureCacheFlush(cache, 0);

                CVPixelBufferLockBaseAddress(bgraOut, kCVPixelBufferLock_ReadOnly);
                uint8_t *base = CVPixelBufferGetBaseAddress(bgraOut);
                size_t stride = CVPixelBufferGetBytesPerRow(bgraOut);
                uint8_t *expected = malloc(kSize * kSize * 4), *swapped = malloc(kSize * kSize * 4);
                uint8_t *got = malloc(kSize * kSize * 4);
                for (size_t y = 0; y < kSize; y++)
                    for (size_t x = 0; x < kSize; x++) {
                        uint8_t *g = base + y * stride + x * 4;
                        uint8_t *e = expected + (y * kSize + x) * 4;
                        uint8_t *s = swapped + (y * kSize + x) * 4;
                        e[0] = outB(x, y); e[1] = outG(x, y); e[2] = outR(x, y); e[3] = 255;
                        s[0] = outR(x, y); s[1] = outG(x, y); s[2] = outB(x, y); s[3] = 255;
                        memcpy(got + (y * kSize + x) * 4, g, 4);
                    }
                CVPixelBufferUnlockBaseAddress(bgraOut, kCVPixelBufferLock_ReadOnly);
                int largest = 0;
                report(@"bgra output written by the GPU, read by the CPU", differences(got, expected, kSize * kSize, 0xf, &largest), largest, NO);
                report(@"bgra output against red and blue swapped (negative control)", differences(got, swapped, kSize * kSize, 0xf, &largest), largest, YES);
                free(expected);
                free(swapped);
                free(got);
            }
            CVPixelBufferRelease(bgraOut);
        }

        [LOG appendFormat:@"CVPLANES-DONE failures %lu\n", (unsigned long)FAILURES];
        printf("%s", [LOG UTF8String]);
        CFRelease(cache);
        return FAILURES ? 1 : 0;
    }
}
