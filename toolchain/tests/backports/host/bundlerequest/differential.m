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

static NSString *revenant_run_path(void)
{
    const char *fromEnvironment = getenv("BUILD");
    if (fromEnvironment == NULL || fromEnvironment[0] == '\0') {
        fprintf(stderr, "differential: BUILD names no run folder, and run.sh sets it\n");
        exit(1);
    }
    return [NSString stringWithUTF8String:fromEnvironment];
}

static NSString *revenant_bundlePath(id self, SEL selector)
{
    (void)self;
    (void)selector;
    return revenant_run_path();
}

@interface RevenantHostNSBundleResourceRequest : NSObject <NSProgressReporting>
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

extern double const RevenantHostNSBundleResourceRequestLoadingPriorityUrgent;
extern void RevenantInstallNSBundleAdditions(Class bundle);
extern NSString *const RevenantHostNSBundleResourceRequestLowDiskSpaceNotification;

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
        Class ours = NSClassFromString(@"RevenantHostNSBundleResourceRequest");
        Class theirs = NSClassFromString(@"NSBundleResourceRequest");
        if (!ours || !theirs) {
            printf("FAIL the backport does not define NSBundleResourceRequest: %d\n", ours != Nil);
            return 1;
        }
        NSBundle *withManifest = makeBundle(@"revenant-brr-with", YES);
        NSBundle *withoutManifest = makeBundle(@"revenant-brr-without", NO);
        NSSet *known = [NSSet setWithObjects:@"level1", @"level2", nil];
        NSSet *unknown = [NSSet setWithObject:@"level9"];

        for (NSString *tag in @[ @"level1", @"level9" ]) {
            id theirs = host_initWithTag(theirs, tag);
            NSString *shown = theirs ? [theirs description] : @"(nil)";
            printf("note: the host private -initWithTag: with %s -> %s\n", [tag UTF8String], [shown UTF8String]);
        }

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
            printf("note: %s - a refusal: %s, level1 reads %g, an unnamed tag reads %g\n",
                   [what UTF8String], reason ? [reason UTF8String] : "(none)", level1, level9);
        }
        Class fresh = objc_allocateClassPair([NSObject class], "RevenantHostFreshBundle", 0);
        class_addMethod(fresh, NSSelectorFromString(@"bundlePath"), (IMP)revenant_bundlePath, "@@:");
        objc_registerClassPair(fresh);
        RevenantInstallNSBundleAdditions(fresh);
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

        printf("note: the fresh class the install was exercised on carries %s\n", [revenant_run_path() UTF8String]);
        printf("note: the host's two NSBundle additions are the same selectors on the same class and read back 0,\n"
               "  so the port's two are held to the header and differ from macOS on purpose.\n");

        same_double(RevenantHostNSBundleResourceRequestLoadingPriorityUrgent, 1.0,
                    @"NSBundleResourceRequestLoadingPriorityUrgent");
        same_string(RevenantHostNSBundleResourceRequestLowDiskSpaceNotification,
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
