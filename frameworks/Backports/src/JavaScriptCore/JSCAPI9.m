#include "../revenant_impl.h"
#import "JSInternal.h"
#import "../RevenantSayOnce.h"


bool BACKPORT_IMPL(JSValueIsArray)(JSContextRef context, JSValueRef value)
{
    return revenant_js_is_array(context, value);
}

bool BACKPORT_IMPL(JSValueIsDate)(JSContextRef context, JSValueRef value)
{
    return revenant_js_is_date(context, value);
}
