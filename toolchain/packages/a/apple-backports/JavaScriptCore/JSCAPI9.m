#import "JSInternal.h"
#import "../RevenantSayOnce.h"


bool JSValueIsArray(JSContextRef context, JSValueRef value)
{
    return revenant_js_is_array(context, value);
}

bool JSValueIsDate(JSContextRef context, JSValueRef value)
{
    return revenant_js_is_date(context, value);
}
