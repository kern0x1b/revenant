// swiftdemo-includes.h -- swift/demo-arm64 with libswiftCore lifted as a guest image. The surface
// is libswiftCore's own libSystem/libobjc imports (dyld_info -imports) beyond the common set.
#include "common-includes.h"
#include <math.h>
#include <execinfo.h>
#include <xlocale.h>
#include <asl.h>
#include <malloc/malloc.h>
#include <dispatch/dispatch.h>
#include <os/lock.h>
#include <os/log.h>
#include <os/signpost.h>
#include <objc/message.h>
