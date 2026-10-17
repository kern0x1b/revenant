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
 * JSValueIsArray and JSValueIsDate ask whether a value inherits from the engine's Array and Date,
 * which is what the release's own `inherits<JSArray>()` and `inherits<DateInstance>()` ask
 * (JSValueRef.cpp:205 and :217). The engine answers that for itself, in script, as Array.isArray
 * and as Object.prototype.toString's [[Class]] - ES5 15.4.3.2 and 15.2.4.2, the same two tests -
 * and charon_js_is_array and charon_js_is_date already ask them of the virtual machine's own
 * context, where no script but this port's runs, so script that replaces either changes nothing and
 * an object that only inherits Array.prototype is neither. -isArray and -isDate answer through these
 * two; there is one answer and one place it is computed.
 */
bool JSValueIsArray(JSContextRef context, JSValueRef value)
{
    return charon_js_is_array(context, value);
}

bool JSValueIsDate(JSContextRef context, JSValueRef value)
{
    return charon_js_is_date(context, value);
}

