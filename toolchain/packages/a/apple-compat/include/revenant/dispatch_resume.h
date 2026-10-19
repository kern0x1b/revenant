#ifndef REVENANT_DISPATCH_RESUME_H
#define REVENANT_DISPATCH_RESUME_H

#include <dispatch/dispatch.h>

#ifdef __cplusplus
extern "C" {
#endif

void revenant_dispatch_resume(dispatch_object_t object);

#ifdef __cplusplus
}
#endif

#define dispatch_resume revenant_dispatch_resume

#endif
