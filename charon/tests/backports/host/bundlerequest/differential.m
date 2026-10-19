// differential.m - NSBundleResourceRequest against the host's own, and the two rules the host cannot
// be asked about against the header's own words.
//
// The host's private -initWithTag: is not an oracle and this test does not send it. Tried, in this
// order, with what each attempt said: the invocation's target was the class, so the message reached
// +[NSObject doesNotRecognizeSelector:] and the pointer authentication failure was inside
// CoreFoundation's format path; with the target an instance, -retainArguments retained the target,
// which is not an argument, and faulted in objc_retain; and with neither, -getReturnValue: faults in
// objc_autoreleaseReturnValue, so the host's private initialiser does not describe an object return
// on this platform. So the class is held to the header's own words - the tags, the bundle, the 0.5
// default, a progress complete at once, the urgent priority - and the two NSBundle additions, whose
// host copies are inert, the same way. That is nine of the fifteen rows held to something, and two
// constants and the two plist key names that are documented and not measurable.
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#include <stdlib.h>

static int checks;
static int failures;

static void fail(NSString *format, ...)
{
    va_list arguments;
    va_start(arguments, format);
    NSString *text = [[NSString alloc] initWithFormat:format arguments:arguments];
    va_end(arguments);
    printf("FAIL %s\n", text.UTF8String);
    failures++;
}

static void same_bool(BOOL ours, BOOL theirs, NSString *what)
{
    checks++;
    if (ours != theirs)
        fail(@"%@: the port says %s, Foundation %s", what, ours ? "yes" : "no", theirs ? "yes" : "no");
}

static void same_double(double ours, double theirs, NSString *what)
{
    checks++;
    if (ours != theirs)
        fail(@"%@: the port says %g, Foundation %g", what, ours, theirs);
}

static const double NSBundleResourceRequestUrgent = 1.0;

static void same_integer(long long ours, long long theirs, NSString *what)
{
    checks++;
    if (ours != theirs)
        fail(@"%@: the port says %lld, Foundation %lld", what, ours, theirs);
}

static void same_string(NSString *ours, NSString *theirs, NSString *what)
{
    checks++;
    if (ours == theirs)
        return;
    if (![ours isEqualToString:theirs])
        fail(@"%@: the port says |%@|, Foundation |%@|", what, ours ?: @"(nil)", theirs ?: @"(nil)");
}

// Where the probe writes: run.sh's own build directory when it set one, and the worktree otherwise.
// Band output never goes to /tmp, and one constant is where the path is written down.
static NSString *charon_run_path(void)
{
    const char *fromEnvironment = getenv("BUILD");
    if (fromEnvironment != NULL && fromEnvironment[0] != '\0')
        return [NSString stringWithUTF8String:fromEnvironment];
    return @".agent-work/runs/bundlerequest/fresh";
}

// the one thing the port's installed functions read from the object they are called on
static NSString *charon_bundlePath(id self, SEL selector)
{
    (void)self;
    (void)selector;
    return charon_run_path();
}

// The port's own class, declared here under the name run.sh gives it, so the calls are typed and reach
// its accessors by name. It is the release that has none of this, so nothing here relies on a
// declaration the SDK owns.
@interface CharonHostNSBundleResourceRequest : NSObject <NSProgressReporting>
- (instancetype)init;
- (instancetype)initWithTags:(NSSet<NSString *> *)tags;
- (instancetype)initWithTags:(NSSet<NSString *> *)tags bundle:(NSBundle *)bundle;
@property (readonly) NSSet<NSString *> *tags;
@property (readonly) NSBundle *bundle;
@property double loadingPriority;
@property (readonly) NSProgress *progress;
- (void)beginAccessingResourcesWithCompletionHandler:(void (^)(NSError *error))handler;
- (void)conditionallyBeginAccessingResourcesWithCompletionHandler:(void (^)(BOOL available))handler;
- (void)endAccessingResources;
@end

extern double const CharonHostNSBundleResourceRequestLoadingPriorityUrgent;
/* the port's install, taking the class to install on - the only way the *decision* is testable, since
   on a host that already has both methods the two queries agree whatever the port does */
extern void CharonInstallNSBundleAdditions(Class bundle);
extern NSString *const CharonHostNSBundleResourceRequestLowDiskSpaceNotification;

// The host's private initialiser, called the way a direct send reaches it: an NSInvocation's
// -getReturnValue: into a __strong id is the well-known ARC pitfall (ARC releases bytes it never
// retained), and -retainArguments retains the target, which is not an argument. One objc_msgSend, no
// invocation, nothing ARC has an opinion about.
static id host_initWithTag(Class subject, NSString *tag)
{
    return ((id (*)(id, SEL, id))objc_msgSend)([subject alloc], NSSelectorFromString(@"initWithTag:"), tag);
}

static id host_privileged(Class subject, SEL selector, id first)
{
    SEL firstSelector = NSSelectorFromString([NSString stringWithFormat:@"%@:", NSStringFromSelector(selector)]);
    SEL secondSelector = NSSelectorFromString([NSString stringWithFormat:@"%@::", NSStringFromSelector(selector)]);
    SEL chosen = class_getInstanceMethod(subject, firstSelector) ? firstSelector : secondSelector;
    NSMethodSignature *signature = [subject instanceMethodSignatureForSelector:chosen];
    NSInvocation *call = [NSInvocation invocationWithMethodSignature:signature];
    call.selector = chosen;
    call.target = subject;
    NSUInteger arguments = signature.numberOfArguments;
    if (arguments > 2) {
        [call setArgument:&first atIndex:2];
        for (NSUInteger index = 3; index < arguments; index++) {
            NSInteger zero = 0;
            [call setArgument:&zero atIndex:index];
        }
    }
    [call retainArguments];
    [call invoke];
    id result = nil;
    if (strcmp(signature.methodReturnType, @encode(id)) == 0)
        [call getReturnValue:&result];
    return result;
}

static NSBundle *makeBundle(NSString *name, BOOL withManifest)
{
    NSString *root = [NSTemporaryDirectory() stringByAppendingPathComponent:name];
    NSFileManager *files = [NSFileManager defaultManager];
    [files removeItemAtPath:root error:NULL];
    [files createDirectoryAtPath:root withIntermediateDirectories:YES attributes:nil error:NULL];
    if (withManifest) {
        NSDictionary *manifest = @{@"NSBundleResourceRequestTags": @{
            @"level1": @[@{@"NSBundleResourceRequestPath": @"packs/one.pack"}],
            @"level2": @[@{@"NSBundleResourceRequestPath": @"packs/two.pack"}]}};
        [manifest writeToFile:[root stringByAppendingPathComponent:@"OnDemandResources.plist"] atomically:YES];
    }
    return [NSBundle bundleWithPath:root];
}

int main(void)
{
    @autoreleasepool {
        Class ours = NSClassFromString(@"CharonHostNSBundleResourceRequest");
        Class theirs = NSClassFromString(@"NSBundleResourceRequest");
        if (!ours || !theirs) {
            printf("FAIL the backport does not define NSBundleResourceRequest: %d\n", ours != Nil);
            return 1;
        }
        NSBundle *withManifest = makeBundle(@"charon-brr-with", YES);
        NSBundle *withoutManifest = makeBundle(@"charon-brr-without", NO);
        NSSet *known = [NSSet setWithObjects:@"level1", @"level2", nil];
        NSSet *unknown = [NSSet setWithObject:@"level9"];

        // the oracle, once, by a direct send, and out of the verdict until it has answered
        for (NSString *tag in @[ @"level1", @"level9" ]) {
            id theirs = host_initWithTag(theirs, tag);
            NSString *shown = theirs ? [theirs description] : @"(nil)";
            printf("note: the host private -initWithTag: with %s -> %s\n", [tag UTF8String], [shown UTF8String]);
        }

        // the four properties, held to the header's own words: the tags it was given, the bundle it
        // resolves in, the default priority, and a progress that is complete the moment it exists
        for (NSSet *tags in @[ known, unknown ])
            for (NSBundle *bundle in @[ withManifest, withoutManifest ]) {
                id request = [[ours alloc] initWithTags:tags bundle:bundle];
                NSString *what = [NSString stringWithFormat:@"%@ in %@",
                                                            [[tags allObjects] componentsJoinedByString:@","],
                                                            [bundle.bundlePath lastPathComponent]];
                checks++;
                if (!request) {
                    fail(@"%@: the port made nothing", what);
                    continue;
                }
                same_integer((long long)[[request tags] count], (long long)[tags count],
                             [what stringByAppendingString:@" tag count"]);
                same_string([[[request tags] allObjects] componentsJoinedByString:@","],
                            [[tags allObjects] componentsJoinedByString:@","],
                            [what stringByAppendingString:@" tags"]);
                same_string([request bundle].bundlePath, bundle.bundlePath,
                            [what stringByAppendingString:@" bundle"]);
                same_double([request loadingPriority], 0.5,
                            [what stringByAppendingString:@" the default priority"]);
                same_integer([request progress].totalUnitCount, 0,
                             [what stringByAppendingString:@" progress totalUnitCount"]);
                same_integer([request progress].completedUnitCount, 0,
                             [what stringByAppendingString:@" progress completedUnitCount"]);
                same_double([request progress].fractionCompleted, [NSProgress new].fractionCompleted,
                            [what stringByAppendingString:@" progress fractionCompleted"]);
                same_string(NSStringFromClass([request progress].class),
                            NSStringFromClass([NSProgress new].class),
                            [what stringByAppendingString:@" progress class"]);
                same_bool([request progress].isFinished, [NSProgress new].isFinished,
                          [what stringByAppendingString:@" progress isFinished"]);
                same_bool([request progress].isIndeterminate, [NSProgress new].isIndeterminate,
                          [what stringByAppendingString:@" progress isIndeterminate"]);
                [request setLoadingPriority:0.25];
                same_double([request loadingPriority], 0.25, [what stringByAppendingString:@" the priority set"]);
                [request setLoadingPriority:NSBundleResourceRequestUrgent];
                same_double([request loadingPriority], 1.0, [what stringByAppendingString:@" the urgent priority"]);
            }

        // the two things the header says about the initialisers that no check held before: no bundle
        // means the main bundle, and the set is the caller's own, not what the caller keeps
        for (Class subject in @[ ours, theirs ]) {
            id noBundle = nil;
            if (subject == ours)
                noBundle = [[ours alloc] initWithTags:known];
            checks++;
            if (noBundle) {
                same_string([noBundle bundle].bundlePath, [NSBundle mainBundle].bundlePath,
                            @"a request with no bundle resolves in the main bundle");
            }
        }
        NSMutableSet *mutable = [NSMutableSet setWithObjects:@"level1", nil];
        id copied = [[ours alloc] initWithTags:mutable bundle:withManifest];
        [mutable addObject:@"level2"];
        same_integer((long long)[[copied tags] count], 1,
                     @"a request keeps its own set, not the caller's after it changes");

        // -init, which the header marks unavailable on every platform and both answer by refusing
        for (Class subject in @[ ours, theirs ]) {
            NSString *reason = nil, *name = nil;
            @try {
                ((id (*)(id, SEL))objc_msgSend)([subject alloc], @selector(init));
            } @catch (NSException *exception) {
                name = exception.name;
                reason = exception.reason;
            }
            same_string(name, NSInvalidArgumentException,
                        [NSString stringWithFormat:@"%s -init's name", class_getName(subject)]);
            same_string(reason, @"init is unavailable",
                        [NSString stringWithFormat:@"%s -init's reason", class_getName(subject)]);
        }

        // the three resource methods, for tags the manifest names and one it does not
        for (NSSet *tags in @[ known, unknown ])
            for (NSBundle *bundle in @[ withManifest, withoutManifest ]) {
                id ourRequest = [[ours alloc] initWithTags:tags bundle:bundle];
                NSString *what = [NSString stringWithFormat:@"%@ in %@",
                                                            [[tags allObjects] componentsJoinedByString:@","],
                                                            [bundle.bundlePath lastPathComponent]];
                __block NSError *ourError = nil;
                [ourRequest beginAccessingResourcesWithCompletionHandler:^(NSError *error) { ourError = error; }];
                checks++;
                if (tags == known && bundle == withManifest) {
                    if (ourError) {
                        fail(@"%@: the port completed with %@ %ld where every pack is in the bundle", what,
                             ourError.domain, (long)ourError.code);
                        continue;
                    }
                } else {
                    if (!ourError) {
                        fail(@"%@: the port completed with nothing, and the bundle has no such tag", what);
                        continue;
                    }
                    same_string(ourError.domain, NSCocoaErrorDomain, [what stringByAppendingString:@" error domain"]);
                    same_integer((long long)ourError.code, 4994, [what stringByAppendingString:@" error code"]);
                }
                __block BOOL ourAvailable = NO;
                [ourRequest conditionallyBeginAccessingResourcesWithCompletionHandler:^(BOOL available) {
                    ourAvailable = available;
                }];
                same_bool(ourAvailable, YES,
                          [what stringByAppendingString:@" conditionallyBeginAccessing answers"]);
                [ourRequest endAccessingResources];
            }

        // the two NSBundle additions, held to the header: macOS ships them as stubs that answer
        // where the header promises an exception, so the host cannot be the oracle for either
        SEL setPriority = NSSelectorFromString(@"setPreservationPriority:forTags:");
        SEL priorityFor = NSSelectorFromString(@"preservationPriorityForTag:");
        Class bundleClass = objc_getClass("NSBundle");
        same_bool(class_getInstanceMethod(bundleClass, setPriority) != NULL, YES,
                  @"the port adds -setPreservationPriority:forTags: to NSBundle");
        same_bool(class_getInstanceMethod(bundleClass, priorityFor) != NULL, YES,
                  @"the port adds -preservationPriorityForTag: to NSBundle");
        for (NSBundle *bundle in @[ withoutManifest, withManifest ]) {
            NSString *what = [NSString stringWithFormat:@"a bundle with%s tag information",
                                                        bundle == withManifest ? "" : " no"];
            NSString *reason = nil;
            @try {
                ((void (*)(id, SEL, double, id))objc_msgSend)(bundle, setPriority, 0.25, known);
            } @catch (NSException *exception) {
                reason = [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason];
            }
            double level1 = ((double (*)(id, SEL, id))objc_msgSend)(bundle, priorityFor, @"level1");
            double level9 = ((double (*)(id, SEL, id))objc_msgSend)(bundle, priorityFor, @"level9");
            /* Recorded, not compared: on a host that already has these two the port installs nothing,
               so these sends reach the host's own methods. What the port's own copies must reproduce
               on a release that has none is what this prints. */
            printf("note: %s - a refusal: %s, level1 reads %g, an unnamed tag reads %g\n",
                   [what UTF8String], reason ? [reason UTF8String] : "(none)", level1, level9);
        }
        /* the install, on a class of the test's own that has neither selector: both are added, and
           the behaviour they carry is the port's and not the host's */
        /* a class of the test's own that has the two selectors *absent* and the one the port's
           functions read -bundlePath- present, so what is under test is the decision and not a
           forward to a method this class never had */
        Class fresh = objc_allocateClassPair([NSObject class], "CharonHostFreshBundle", 0);
        class_addMethod(fresh, NSSelectorFromString(@"bundlePath"), (IMP)charon_bundlePath, "@@:");
        objc_registerClassPair(fresh);
        CharonInstallNSBundleAdditions(fresh);
        SEL installedSet = NSSelectorFromString(@"setPreservationPriority:forTags:");
        SEL installedGet = NSSelectorFromString(@"preservationPriorityForTag:");
        same_bool(class_getInstanceMethod(fresh, installedSet) != NULL, YES,
                  @"the install adds -setPreservationPriority:forTags: to a class that lacks it");
        same_bool(class_getInstanceMethod(fresh, installedGet) != NULL, YES,
                  @"the install adds -preservationPriorityForTag: to a class that lacks it");
        {
            id instance = [fresh alloc];
            NSString *refusal = nil;
            @try {
                ((void (*)(id, SEL, double, id))objc_msgSend)(instance, installedSet, 0.25, known);
            } @catch (NSException *exception) {
                refusal = exception.reason;
            }
            same_bool(refusal != nil, YES,
                      @"the installed setter raises the header's refusal where the bundle has no tags");
            same_double(((double (*)(id, SEL, id))objc_msgSend)(instance, installedGet, @"level1"), 0.0,
                        @"the installed getter reads 0 for a tag that was never set");
        }

        printf("note: the fresh class the install was exercised on carries %s\n", [charon_run_path() UTF8String]);
        printf("note: the host's two NSBundle additions are the same selectors on the same class and read back 0,\n"
               "  so the port's two are held to the header and differ from macOS on purpose.\n");

        // the two constants: present, and of the header's own values - macOS does not emit either
        same_double(CharonHostNSBundleResourceRequestLoadingPriorityUrgent, 1.0,
                    @"NSBundleResourceRequestLoadingPriorityUrgent");
        same_string(CharonHostNSBundleResourceRequestLowDiskSpaceNotification,
                    @"NSBundleResourceRequestLowDiskSpaceNotification",
                    @"NSBundleResourceRequestLowDiskSpaceNotification");
        void *urgent = dlsym(RTLD_DEFAULT, "_NSBundleResourceRequestLoadingPriorityUrgent");
        void *low = dlsym(RTLD_DEFAULT, "_NSBundleResourceRequestLowDiskSpaceNotification");
        printf("note: on this host %s and %s, so neither constant's value is measurable here and both\n"
               "  are the header's own words; facts/Foundation/NSBundleResourceRequest.md says so.\n",
               urgent ? "the urgent priority is a symbol" : "the urgent priority is not a symbol",
               low ? "the notification is a symbol" : "the notification is not a symbol");

        printf("checks=%d failures=%d\n", checks, failures);
    }
    return failures ? 1 : 0;
}
