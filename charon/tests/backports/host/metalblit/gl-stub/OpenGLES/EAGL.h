// EAGL.h — the declarations CharonMetal.h needs to be parsed on a host with no OpenGL ES.
//
// The Command Line Tools' iOSSupport has no OpenGLES.framework, because Catalyst has no OpenGL, and
// CharonMetal.h opens with EAGL and GL. This is the whole of what that header names: five typedefs and
// one class. No function and no constant is declared, on purpose — the port's CPU paths call no GL at
// all, so if a file under test ever starts to, it fails to link here instead of quietly passing.
#ifndef CHARON_HOST_EAGL_H
#define CHARON_HOST_EAGL_H

typedef unsigned int GLenum;
typedef int GLint;
typedef unsigned int GLuint;
typedef int GLsizei;
typedef float GLfloat;
typedef unsigned char GLboolean;

@interface EAGLContext : NSObject
@end

#endif
