#ifndef CHARON_DISPATCH_RESUME_H
#define CHARON_DISPATCH_RESUME_H

#include <dispatch/dispatch.h>

#ifdef __cplusplus
extern "C" {
#endif

void charon_dispatch_resume(dispatch_object_t object);

#ifdef __cplusplus
}
#endif

#define dispatch_resume charon_dispatch_resume

#endif
