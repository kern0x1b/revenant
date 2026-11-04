#include "../revenant_impl.h"
#import "JSInternal.h"
#import "../RevenantSayOnce.h"


void BACKPORT_IMPL(JSGlobalContextSetInspectable)(JSGlobalContextRef context, bool inspectable)
{
    (void)context;
    (void)inspectable;
    revenant_say_once_for(@"JavaScriptCore.JSGlobalContextSetInspectable",
                       @"JavaScriptCore: JSGlobalContextSetInspectable does nothing here: the flag is read by a Web "
                       @"Inspector deciding whether it may attach, and this port carries none.");
}

bool BACKPORT_IMPL(JSGlobalContextIsInspectable)(JSGlobalContextRef context)
{
    (void)context;
    return false;
}
