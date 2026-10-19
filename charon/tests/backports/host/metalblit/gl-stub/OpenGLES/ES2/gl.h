// gl.h — see EAGL.h beside it: the declarations CharonMetal.h needs to be parsed on a host with no
// OpenGL ES, and nothing else. CharonMetal.h imports this for the types EAGL.h already gave, and for
// the ES 2.0 entry points it names in its comments; none of those is declared here, so a port file
// that reached for one would not link.
#ifndef CHARON_HOST_GLES2_GL_H
#define CHARON_HOST_GLES2_GL_H
#import <OpenGLES/EAGL.h>
#endif
