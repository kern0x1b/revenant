#import "RevenantSCNJitterBuffers.h"
#import <OpenGLES/ES2/glext.h>

static const char *RevenantSCNJitterVertexSource =
    "attribute vec2 a_position;\n"
    "varying vec2 v_uv;\n"
    "void main() {\n"
    "    v_uv = a_position * 0.5 + 0.5;\n"
    "    gl_Position = vec4(a_position, 0.0, 1.0);\n"
    "}\n";

static const char *RevenantSCNJitterCopySource =
    "precision mediump float;\n"
    "varying vec2 v_uv;\n"
    "uniform sampler2D u_texture;\n"
    "void main() {\n"
    "    gl_FragColor = texture2D(u_texture, v_uv);\n"
    "}\n";

static const char *RevenantSCNJitterMixSource =
    "precision mediump float;\n"
    "varying vec2 v_uv;\n"
    "uniform sampler2D u_sample;\n"
    "uniform sampler2D u_accumulated;\n"
    "uniform float u_weight;\n"
    "void main() {\n"
    "    gl_FragColor = mix(texture2D(u_accumulated, v_uv), texture2D(u_sample, v_uv), u_weight);\n"
    "}\n";

static const GLfloat RevenantSCNJitterQuad[8] = {-1, -1, 1, -1, -1, 1, 1, 1};

static GLuint RevenantSCNJitterCompile(GLenum type, const char *source)
{
    GLuint shader = glCreateShader(type);
    glShaderSource(shader, 1, &source, NULL);
    glCompileShader(shader);
    GLint status = GL_FALSE;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &status);
    if (status != GL_TRUE) {
        glDeleteShader(shader);
        return 0;
    }
    return shader;
}

static GLuint RevenantSCNJitterProgram(const char *fragmentSource)
{
    GLuint vertex = RevenantSCNJitterCompile(GL_VERTEX_SHADER, RevenantSCNJitterVertexSource);
    GLuint fragment = RevenantSCNJitterCompile(GL_FRAGMENT_SHADER, fragmentSource);
    GLuint program = 0;
    if (vertex && fragment) {
        program = glCreateProgram();
        glAttachShader(program, vertex);
        glAttachShader(program, fragment);
        glBindAttribLocation(program, 0, "a_position");
        glLinkProgram(program);
        GLint linked = GL_FALSE;
        glGetProgramiv(program, GL_LINK_STATUS, &linked);
        if (linked != GL_TRUE) {
            glDeleteProgram(program);
            program = 0;
        }
    }
    if (vertex) {
        glDeleteShader(vertex);
    }
    if (fragment) {
        glDeleteShader(fragment);
    }
    return program;
}

static GLuint RevenantSCNJitterTexture(GLint width, GLint height)
{
    GLuint texture = 0;
    glGenTextures(1, &texture);
    glBindTexture(GL_TEXTURE_2D, texture);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    return texture;
}

@implementation RevenantSCNJitterBuffers
{
    GLuint _sampleFramebuffer, _sampleTexture, _sampleDepth;
    GLuint _accumFramebuffers[2], _accumTextures[2];
    NSUInteger _current;
    NSUInteger _accumulated;
    GLuint _copyProgram, _mixProgram, _quadBuffer;
    GLint _positionLocation, _textureLocation, _sampleLocation, _accumulatedLocation, _weightLocation;
    GLint _width, _height;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _copyProgram = RevenantSCNJitterProgram(RevenantSCNJitterCopySource);
        _mixProgram = RevenantSCNJitterProgram(RevenantSCNJitterMixSource);
        if (_copyProgram && _mixProgram) {
            _positionLocation = glGetAttribLocation(_copyProgram, "a_position");
            _textureLocation = glGetUniformLocation(_copyProgram, "u_texture");
            _sampleLocation = glGetUniformLocation(_mixProgram, "u_sample");
            _accumulatedLocation = glGetUniformLocation(_mixProgram, "u_accumulated");
            _weightLocation = glGetUniformLocation(_mixProgram, "u_weight");
        }
        glGenBuffers(1, &_quadBuffer);
        glBindBuffer(GL_ARRAY_BUFFER, _quadBuffer);
        glBufferData(GL_ARRAY_BUFFER, sizeof(RevenantSCNJitterQuad), RevenantSCNJitterQuad, GL_STATIC_DRAW);
    }
    return self;
}

- (BOOL)isUsable
{
    return _copyProgram != 0 && _mixProgram != 0;
}

- (void)deleteTargets
{
    if (_sampleFramebuffer) {
        glDeleteFramebuffers(1, &_sampleFramebuffer);
    }
    if (_sampleTexture) {
        glDeleteTextures(1, &_sampleTexture);
    }
    if (_sampleDepth) {
        glDeleteRenderbuffers(1, &_sampleDepth);
    }
    for (NSUInteger index = 0; index < 2; index++) {
        if (_accumFramebuffers[index]) {
            glDeleteFramebuffers(1, &_accumFramebuffers[index]);
        }
        if (_accumTextures[index]) {
            glDeleteTextures(1, &_accumTextures[index]);
        }
        _accumFramebuffers[index] = _accumTextures[index] = 0;
    }
    _sampleFramebuffer = _sampleTexture = _sampleDepth = 0;
    _current = 0;
    _accumulated = 0;
    _width = _height = 0;
}

- (void)resizeToWidth:(GLint)width height:(GLint)height
{
    if (width == _width && height == _height && _sampleFramebuffer) {
        return;
    }
    [self deleteTargets];
    _width = width;
    _height = height;
    glGenFramebuffers(1, &_sampleFramebuffer);
    _sampleTexture = RevenantSCNJitterTexture(width, height);
    glGenRenderbuffers(1, &_sampleDepth);
    glBindRenderbuffer(GL_RENDERBUFFER, _sampleDepth);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT16, width, height);
    glBindFramebuffer(GL_FRAMEBUFFER, _sampleFramebuffer);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, _sampleTexture, 0);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, _sampleDepth);
    for (NSUInteger index = 0; index < 2; index++) {
        glGenFramebuffers(1, &_accumFramebuffers[index]);
        _accumTextures[index] = RevenantSCNJitterTexture(width, height);
        glBindFramebuffer(GL_FRAMEBUFFER, _accumFramebuffers[index]);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, _accumTextures[index], 0);
    }
}

- (void)drawQuad
{
    glBindBuffer(GL_ARRAY_BUFFER, _quadBuffer);
    glEnableVertexAttribArray(_positionLocation);
    glVertexAttribPointer(_positionLocation, 2, GL_FLOAT, GL_FALSE, 0, NULL);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    glDisableVertexAttribArray(_positionLocation);
}

- (void)prepareDraw
{
    glDisable(GL_DEPTH_TEST);
    glDisable(GL_CULL_FACE);
    glDisable(GL_STENCIL_TEST);
    glDisable(GL_SCISSOR_TEST);
    glDisable(GL_BLEND);
}

- (void)bindSampleFramebuffer
{
    glBindFramebuffer(GL_FRAMEBUFFER, _sampleFramebuffer);
    glViewport(0, 0, _width, _height);
}

- (void)accumulateSampleWithWeight:(float)weight
{
    NSUInteger next = 1 - _current;
    glBindFramebuffer(GL_FRAMEBUFFER, _accumFramebuffers[next]);
    glViewport(0, 0, _width, _height);
    [self prepareDraw];
    glUseProgram(_mixProgram);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, _sampleTexture);
    glUniform1i(_sampleLocation, 0);
    glActiveTexture(GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_2D, _accumTextures[_current]);
    glUniform1i(_accumulatedLocation, 1);
    glUniform1f(_weightLocation, weight);
    [self drawQuad];
    glActiveTexture(GL_TEXTURE0);
    _current = next;
    _accumulated = _accumulated + 1;
}

- (void)presentToFramebuffer:(GLuint)framebuffer
{
    glBindFramebuffer(GL_FRAMEBUFFER, framebuffer);
    glViewport(0, 0, _width, _height);
    [self prepareDraw];
    glUseProgram(_copyProgram);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, _accumTextures[_current]);
    glUniform1i(_textureLocation, 0);
    [self drawQuad];
}

- (void)dispose
{
    [self deleteTargets];
    if (_copyProgram) {
        glDeleteProgram(_copyProgram);
        _copyProgram = 0;
    }
    if (_mixProgram) {
        glDeleteProgram(_mixProgram);
        _mixProgram = 0;
    }
    if (_quadBuffer) {
        glDeleteBuffers(1, &_quadBuffer);
        _quadBuffer = 0;
    }
}

@end
