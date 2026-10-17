#import "JSInternal.h"
#import "../CharonSayOnce.h"

/*
 * The C API of a JavaScriptCore the release does not export, answered by asking the release's own
 * engine. Every function here is a question the 2012 engine can be asked and the SDK dates after
 * iOS 6; what each one is, and the primitive of the release's own export table that answers it, is
 * in facts/JavaScriptCore/CAPI.md, and tests/backports/host/jscontext/checks.m holds each one to the
 * host's own JavaScriptCore.
 *
 * The release's C API is what this answers over, and nothing called here is absent from it. Directly:
 * JSValueToStringCopy, JSStringRelease and the four property functions. Through the two helpers of
 * JSInternal.m: JSValueIsObject, JSValueToBoolean, JSStringIsEqualToUTF8CString, JSObjectCallAsFunction
 * and the rest of what charon_js_is_array and charon_js_is_date ask. All exported since 3.0
 * (first-rung.lua over the 50 held rungs, the oldest held rung carrying each), each present in the 6.1.3
 * armv7 cache and in the 4.3 one this package also builds.
 */


/*
 * ONE FILE PER RELEASE, and this family needed four. The eleven functions below are the API of four
 * Apple releases and an object carries one of them, so they are four objects: JSCAPI8.m
 * (JSGlobalContextSetName, JSGlobalContextCopyName), JSCAPI9.m (JSValueIsArray, JSValueIsDate),
 * JSCAPI16.m (JSValueIsSymbol and the four JSObject...ForKey) and JSCAPI18.m
 * (JSGlobalContextSetInspectable, JSGlobalContextIsInspectable). What decides the four is not the
 * `introduced` field of a registry row, which is where Apple published each name and is right about
 * that, but the first held release that EXPORTS the symbol - the measurement
 * modules/apple/backports.lua's check_releases() makes through modules/apple/dyld.lua's
 * first_releases(), and the one that refused the single JSCAPI.m. Measured with it, quoting the call:
 *
 *   JSGlobalContextSetName, JSGlobalContextCopyName                 8.0   exported from 8.0 on
 *   JSValueIsArray, JSValueIsDate                                   9.0   exported from 9.0 on
 *   JSValueIsSymbol, JSObject{Get,Set,Has,Delete}PropertyForKey    16.0  exported by 16.0 and 18.0
 *   JSGlobalContextSetInspectable, JSGlobalContextIsInspectable     18.0  exported by 18.0
 *
 * The 13.0 and 16.4 rows read as 16.0 and 18.0 for the same reason MPSNNReduceUnary reads as 16.0
 * rather than the 11.3 its header annotation says: no release between 12.0 and 16.0 is held, and none
 * between 16.0 and 18.0, so a name Apple published inside a gap is bounded from above by the next rung
 * that exports it. tools/release-split.lua prints the same note when its ladder skips a major release.
 */

/*
 * ToPropertyKey, as JSObjectRef.cpp's four ForKey functions do it: a string key is the name
 * itself, and anything else is ToString, which for a number is the same string the engine's own
 * property lookup would have formed and for an object runs its toString/valueOf and can throw. The
 * release's JSValueToStringCopy is ES ToString, so it is both cases, and a key of the symbol type -
 * the one kind ToPropertyKey answers that ToString does not - cannot arise: no value of the 2012
 * engine is a symbol (JSC::Symbol is 0 among the 300 JSC:: symbols the 6.1.3 cache carries).
 * *exception must start NULL; the name is returned for the caller to release, and NULL only when
 * the key itself threw, with the exception left where the caller reads it.
 */
static JSStringRef PropertyName(JSContextRef context, JSValueRef key, JSValueRef *exception)
{
    return JSValueToStringCopy(context, key, exception);
}

/*
 * The release's engine has no symbol type: JSC::Symbol is 0 among the JSC:: symbols its own cache
 * carries, and nothing of this port makes one - +[JSValue valueWithNewSymbolFromDescription:]
 * refuses at the seam with a TypeError, for the same reason. So no value this engine can hold is a
 * symbol and the answer for every one of them is false, which is also the answer the release with
 * symbols gives for every value that is not a symbol. This row is carried so a client can find that
 * out before it calls JSValueMakeSymbol(), which this port does not carry: a weak reference to that
 * one is NULL.
 */
bool JSValueIsSymbol(JSContextRef context, JSValueRef value)
{
    (void)context;
    (void)value;
    return false;
}

/*
 * The four property functions of a value key, which is the string-keyed property API of the release
 * reached through ToPropertyKey. The release's own JSObjectGetProperty, JSObjectSetProperty,
 * JSObjectHasProperty and JSObjectDeleteProperty do the work; the key is the only thing added, and
 * the same way JSC's get, put, hasProperty and deleteProperty take an Identifier.
 *
 * The exception out-parameter the SDK's signature of the three of them carries is passed straight
 * through, so a getter or a setter that throws leaves it where the caller reads it. Every other
 * call of these four in this package already passes the SDK's arity with NULL there - JSValue.m's
 * NamedProperty and every property read of JSExportBridge.m - and answers correctly on a 6.1.3
 * device (facts/JavaScriptCore/JSContext.md, 151 of 151 on an iPad 2), so a release whose own
 * function takes no such argument is reading none of it.
 */
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

