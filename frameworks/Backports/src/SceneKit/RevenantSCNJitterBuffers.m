#import "RevenantSCNJitterBuffers.h"
#import <OpenGLES/ES2/glext.h>

static const char *RevenantSCNJitterVertexSource =
    "attribute vec2 a_position;\n"
    "varying vec2 v_uv;\n"
    "void main() {\n"
    "    v_uv = a_position * 0.5 + 0.5;\n"
    "    gl_Position = vec4(a_position, 0.0, 1.0);\n"
    "}\n";

static const char *RevenantSCNJitterFragmentSource =
    "precision mediump float;\n"
    "varying vec2 v_uv;\n"
    "uniform sampler2D u_texture;\n"
    "void main() {\n"
    "    gl_FragColor = texture2D(u_texture, v_uv);\n"
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
    GLuint _accumFramebuffer, _accumTexture;
    GLuint _program, _quadBuffer;
    GLint _positionLocation, _textureLocation;
    GLint _width, _height;
}

- (instancetype)init
{
    if ((self = [super init])) {
        GLuint vertex = RevenantSCNJitterCompile(GL_VERTEX_SHADER, RevenantSCNJitterVertexSource);
        GLuint fragment = RevenantSCNJitterCompile(GL_FRAGMENT_SHADER, RevenantSCNJitterFragmentSource);
        if (vertex && fragment) {
            _program = glCreateProgram();
            glAttachShader(_program, vertex);
            glAttachShader(_program, fragment);
            glBindAttribLocation(_program, 0, "a_position");
            glLinkProgram(_program);
            GLint linked = GL_FALSE;
            glGetProgramiv(_program, GL_LINK_STATUS, &linked);
            if (linked == GL_TRUE) {
                _positionLocation = glGetAttribLocation(_program, "a_position");
                _textureLocation = glGetUniformLocation(_program, "u_texture");
            } else {
                glDeleteProgram(_program);
                _program = 0;
            }
        }
        if (vertex) {
            glDeleteShader(vertex);
        }
        if (fragment) {
            glDeleteShader(fragment);
        }
        glGenBuffers(1, &_quadBuffer);
        glBindBuffer(GL_ARRAY_BUFFER, _quadBuffer);
        glBufferData(GL_ARRAY_BUFFER, sizeof(RevenantSCNJitterQuad), RevenantSCNJitterQuad, GL_STATIC_DRAW);
    }
    return self;
}

- (BOOL)isUsable
{
    return _program != 0;
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
    if (_accumFramebuffer) {
        glDeleteFramebuffers(1, &_accumFramebuffer);
    }
    if (_accumTexture) {
        glDeleteTextures(1, &_accumTexture);
    }
    _sampleFramebuffer = _sampleTexture = _sampleDepth = _accumFramebuffer = _accumTexture = 0;
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
    glGenFramebuffers(1, &_accumFramebuffer);
    _accumTexture = RevenantSCNJitterTexture(width, height);
    glBindFramebuffer(GL_FRAMEBUFFER, _accumFramebuffer);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, _accumTexture, 0);
}

- (void)drawTexture:(GLuint)texture
{
    glUseProgram(_program);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, texture);
    glUniform1i(_textureLocation, 0);
    glBindBuffer(GL_ARRAY_BUFFER, _quadBuffer);
    glEnableVertexAttribArray(_positionLocation);
    glVertexAttribPointer(_positionLocation, 2, GL_FLOAT, GL_FALSE, 0, NULL);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    glDisableVertexAttribArray(_positionLocation);
}

- (void)bindSampleFramebuffer
{
    glBindFramebuffer(GL_FRAMEBUFFER, _sampleFramebuffer);
    glViewport(0, 0, _width, _height);
}

- (void)accumulateSampleWithWeight:(float)weight
{
    glBindFramebuffer(GL_FRAMEBUFFER, _accumFramebuffer);
    glViewport(0, 0, _width, _height);
    glEnable(GL_BLEND);
    glBlendColor(0, 0, 0, weight);
    glBlendFunc(GL_CONSTANT_ALPHA, GL_ONE_MINUS_CONSTANT_ALPHA);
    [self drawTexture:_sampleTexture];
    glDisable(GL_BLEND);
}

- (void)presentToFramebuffer:(GLuint)framebuffer
{
    glBindFramebuffer(GL_FRAMEBUFFER, framebuffer);
    glViewport(0, 0, _width, _height);
    glDisable(GL_BLEND);
    [self drawTexture:_accumTexture];
}

- (void)dispose
{
    [self deleteTargets];
    if (_program) {
        glDeleteProgram(_program);
        _program = 0;
    }
    if (_quadBuffer) {
        glDeleteBuffers(1, &_quadBuffer);
        _quadBuffer = 0;
    }
}

@end
