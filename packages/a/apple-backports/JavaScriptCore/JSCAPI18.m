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
 * A context's name and its inspectable flag are the Web Inspector's two fields for a context:
 * what the inspector lists a context under, and whether it may attach to it at all. This port
 * carries no Web Inspector - there is no protocol here that could be refused or attached - so
 * nothing on it reads either. They are carried, they answer what this port can answer - nothing, and a
 * NULL or a NO - and the three that are reached to set or to report something say so in the log the
 * first time an application calls them, which is what a row marked inert is for: SetName, CopyName and
 * SetInspectable. IsInspectable is the fourth and the only one that says nothing, because a question
 * that reads a flag nothing on this port sets is not a thing to report. None of the four is bridged to
 * -[JSContext name] and -[JSContext setInspectable:], which keep
 * their own value in the wrapper: that registry holds wrappers weakly, by design, so a store a C
 * client could reach would have to outlive the wrapper and die with the context, and the only such
 * store the release has - a JSWeakObjectMap - holds JavaScript values rather than a name. Stated
 * here rather than left to be found by a client that mixes the two.
 */
void JSGlobalContextSetInspectable(JSGlobalContextRef context, bool inspectable)
{
    (void)context;
    (void)inspectable;
    charon_say_once_for(@"JavaScriptCore.JSGlobalContextSetInspectable",
                       @"JavaScriptCore: JSGlobalContextSetInspectable does nothing here: the flag is read by a Web "
                       @"Inspector deciding whether it may attach, and this port carries none.");
}

bool JSGlobalContextIsInspectable(JSGlobalContextRef context)
{
    (void)context;
    return false;
}
