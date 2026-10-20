#import "JSInternal.h"
#import "../RevenantSayOnce.h"


void JSGlobalContextSetInspectable(JSGlobalContextRef context, bool inspectable)
{
    (void)context;
    (void)inspectable;
    revenant_say_once_for(@"JavaScriptCore.JSGlobalContextSetInspectable",
                       @"JavaScriptCore: JSGlobalContextSetInspectable does nothing here: the flag is read by a Web "
                       @"Inspector deciding whether it may attach, and this port carries none.");
}

bool JSGlobalContextIsInspectable(JSGlobalContextRef context)
{
    (void)context;
    return false;
}
