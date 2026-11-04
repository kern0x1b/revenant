#include "../revenant_impl.h"
#import "JSInternal.h"
#import "../RevenantSayOnce.h"


void BACKPORT_IMPL(JSGlobalContextSetName)(JSGlobalContextRef context, JSStringRef name)
{
    (void)context;
    (void)name;
    revenant_say_once_for(@"JavaScriptCore.JSGlobalContextSetName",
                       @"JavaScriptCore: JSGlobalContextSetName does nothing here: a context's name is shown by a "
                       @"Web Inspector, and this port carries none. -[JSContext setName:] keeps a name in its own "
                       @"wrapper, which the two do not share.");
}

JSStringRef BACKPORT_IMPL(JSGlobalContextCopyName)(JSGlobalContextRef context)
{
    (void)context;
    revenant_say_once_for(@"JavaScriptCore.JSGlobalContextCopyName",
                       @"JavaScriptCore: JSGlobalContextCopyName answers NULL here: a context's name is shown by a "
                       @"Web Inspector, and this port carries none.");
    return NULL;
}
