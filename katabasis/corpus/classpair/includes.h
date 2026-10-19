// includes.h -- the surface main.c's translation bridges: the common C surface, the runtime, and Foundation's NSObject (an
// app's own includes header brings its messages, and a message with no generated bridge takes the slower path that is
// marshalled from the runtime's type encoding).
#include "../../targets/common-includes.h"
#include <objc/runtime.h>
#include <objc/message.h>
#import <Foundation/Foundation.h>
