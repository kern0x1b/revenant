#import <Foundation/Foundation.h>
#import <objc/runtime.h>
static void P(NSString *f, ...) NS_FORMAT_FUNCTION(1,2);
static void P(NSString *f, ...) { va_list a; va_start(a,f); NSString *s=[[NSString alloc] initWithFormat:f arguments:a]; va_end(a); printf("%s\n", s.UTF8String); }

/* What the host can be asked about NSBundleResourceRequest, and what it cannot, now that the class's
   initialisers have been measured as raising. This step is the other half: the bundle side, which is
   where the port's real work is. */
int main(void) { setvbuf(stdout, NULL, _IONBF, 0); @autoreleasepool {
    Class request = NSClassFromString(@"NSBundleResourceRequest");
    P(@"class %s, methods:", class_getName(request));
    unsigned n = 0;
    Method *m = class_copyMethodList(request, &n);
    for (unsigned i = 0; i < n; i++)
        P(@"  -%@", NSStringFromSelector(method_getName(m[i])));
    free(m);
    unsigned c = 0;
    Method *cm = class_copyMethodList(object_getClass(request), &c);
    P(@"class methods:");
    for (unsigned i = 0; i < c; i++)
        P(@"  +%@", NSStringFromSelector(method_getName(cm[i])));
    free(cm);
    P(@"--- the two NSBundle additions, which are API_UNAVAILABLE(macOS): what the host answers");
    P(@"  setPreservationPriority:forTags: %s", [NSBundle instancesRespondToSelector:@selector(setPreservationPriority:forTags:)] ? "answers" : "NO");
    P(@"  preservationPriorityForTag:  %s", [NSBundle instancesRespondToSelector:@selector(preservationPriorityForTag:)] ? "answers" : "NO");
    P(@"  the class %s exists on the host: %s", "NSBundle", "yes");
    P(@"--- the bundle a port reads: what the release's own NSBundle can be asked for");
    NSBundle *main = [NSBundle mainBundle];
    P(@"  main bundle: %@", main.bundlePath);
    NSString *mainPlist = [main pathForResource:@"OnDemandResources" ofType:@"plist"];
    P(@"  OnDemandResources.plist in it: %@", mainPlist ?: @"(none)");
    P(@"  a bundle made now, with such a plist written into it:");
    NSString *root = [NSTemporaryDirectory() stringByAppendingPathComponent:@"brr"];
    [[NSFileManager defaultManager] createDirectoryAtPath:root withIntermediateDirectories:YES attributes:nil error:NULL];
    NSDictionary *packs = @{ @"level1": @[ @{ @"NSBundleResourceRequestPath": @"packs/one.pack" } ],
                             @"level2": @[ @{ @"NSBundleResourceRequestPath": @"packs/two.pack" } ] };
    NSDictionary *manifest = @{ @"NSBundleResourceRequestTags": packs };
    [manifest writeToFile:[root stringByAppendingPathComponent:@"OnDemandResources.plist"] atomically:YES];
    P(@"    wrote |%@|", manifest);
    NSBundle *made = [NSBundle bundleWithPath:root];
    NSString *madePlist = [made pathForResource:@"OnDemandResources" ofType:@"plist"];
    P(@"    NSBundle reads it back: %@", madePlist ?: @"(none)");
    P(@"    urlForResource:withExtension: -> %@", [made URLForResource:@"OnDemandResources" withExtension:@"plist"] ?: @"(nil)");
    P(@"--- the two attribute names, by dlsym, the host's own values");
    const char *names[] = { "_NSBundleResourceRequestLoadingPriorityUrgent", "_NSBundleResourceRequestLowDiskSpaceNotification" };
    for (unsigned i = 0; i < 2; i++) {
        void *address = dlsym(RTLD_DEFAULT, names[i]);
        if (!address) { P(@"  %s: no symbol on the host", names[i] + 1); continue; }
        if (i == 0)
            P(@"  %s = %g", names[i] + 1, *(double *)address);
        else {
            id note = *(__unsafe_unretained id *)address;
            P(@"  %s = |%@| (%s)", names[i] + 1, [note description], class_getName([note class]));
        }
    }
} return 0; }
