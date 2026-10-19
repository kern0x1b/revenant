#import "JSInternal.h"
#import "../CharonSayOnce.h"


static JSStringRef PropertyName(JSContextRef context, JSValueRef key, JSValueRef *exception)
{
    return JSValueToStringCopy(context, key, exception);
}

bool JSValueIsSymbol(JSContextRef context, JSValueRef value)
{
    (void)context;
    (void)value;
    return false;
}

JSValueRef JSObjectGetPropertyForKey(JSContextRef context, JSObjectRef object, JSValueRef propertyKey, JSValueRef *exception)
{
    JSStringRef name = PropertyName(context, propertyKey, exception);
    if (!name)
        return NULL;
    JSValueRef value = JSObjectGetProperty(context, object, name, exception);
    JSStringRelease(name);
    return value;
}

bool JSObjectHasPropertyForKey(JSContextRef context, JSObjectRef object, JSValueRef propertyKey, JSValueRef *exception)
{
    JSStringRef name = PropertyName(context, propertyKey, exception);
    if (!name)
        return false;
    bool has = JSObjectHasProperty(context, object, name);
    JSStringRelease(name);
    return has;
}

void JSObjectSetPropertyForKey(JSContextRef context, JSObjectRef object, JSValueRef propertyKey, JSValueRef value,
                               JSPropertyAttributes attributes, JSValueRef *exception)
{
    JSStringRef name = PropertyName(context, propertyKey, exception);
    if (!name)
        return;
    JSObjectSetProperty(context, object, name, value, attributes, exception);
    JSStringRelease(name);
}

bool JSObjectDeletePropertyForKey(JSContextRef context, JSObjectRef object, JSValueRef propertyKey, JSValueRef *exception)
{
    JSStringRef name = PropertyName(context, propertyKey, exception);
    if (!name)
        return false;
    bool deleted = JSObjectDeleteProperty(context, object, name, exception);
    JSStringRelease(name);
    return deleted;
}
