#import "JSInternal.h"
#import "../CharonSayOnce.h"


bool JSValueIsArray(JSContextRef context, JSValueRef value)
{
    return charon_js_is_array(context, value);
}

bool JSValueIsDate(JSContextRef context, JSValueRef value)
{
    return charon_js_is_date(context, value);
}
