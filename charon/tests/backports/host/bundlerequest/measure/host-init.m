#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>
static void P(NSString *f, ...) NS_FORMAT_FUNCTION(1,2);
static void P(NSString *f, ...) { va_list a; va_start(a,f); NSString *s=[[NSString alloc] initWithFormat:f arguments:a]; va_end(a); printf("%s\n", s.UTF8String); }
int main(void) { setvbuf(stdout, NULL, _IONBF, 0); @autoreleasepool {
    Class request = NSClassFromString(@"NSBundleResourceRequest");
    @try { id made = ((id(*)(id,SEL))objc_msgSend)([request alloc], @selector(init));
           P(@"-init -> %s", made ? "an object" : "(nil)"); }
    @catch (NSException *e) { P(@"-init -> %@: %@", e.name, e.reason); }
    @try { id made = ((id(*)(id,SEL,id))objc_msgSend)([request alloc], @selector(initWithTag:), @"one");
           P(@"-initWithTag: -> %s", made ? "an object" : "(nil)"); }
    @catch (NSException *e) { P(@"-initWithTag: -> %@: %@", e.name, e.reason); }
    P(@"--- the two NSBundle additions, and the refusal the header promises");
    // the two additions are API_UNAVAILABLE(macOS), so they are reached by name, the way the port
    // will reach them: nothing here links a symbol the platform does not export
    SEL setPriority = NSSelectorFromString(@"setPreservationPriority:forTags:");
    SEL priorityFor = NSSelectorFromString(@"preservationPriorityForTag:");
    NSBundle *noTags = [NSBundle mainBundle];
    NSSet *level1 = [NSSet setWithObject:@"level1"];
    @try { ((void(*)(id,SEL,double,id))objc_msgSend)(noTags, setPriority, 0.5, level1);
           P(@"setPreservationPriority:forTags: on a bundle with no tags -> answered"); }
    @catch (NSException *e) { P(@"  on a bundle with no tags -> %@: %@", e.name, e.reason); }
    P(@"preservationPriorityForTag: on a bundle with no tags -> %g",
      ((double(*)(id,SEL,id))objc_msgSend)(noTags, priorityFor, @"level1"));
    @try { ((void(*)(id,SEL,double,id))objc_msgSend)(noTags, setPriority, 2.0, level1);
           P(@"an out-of-range priority -> answered"); }
    @catch (NSException *e) { P(@"  an out-of-range priority -> %@: %@", e.name, e.reason); }
    /* a bundle with a manifest, so both have tags to work on */
    NSString *root = [NSTemporaryDirectory() stringByAppendingPathComponent:@"brr2"];
    [[NSFileManager defaultManager] createDirectoryAtPath:root withIntermediateDirectories:YES attributes:nil error:NULL];
    NSDictionary *manifest = @{ @"NSBundleResourceRequestTags": @{ @"level1": @[ @{ @"NSBundleResourceRequestPath": @"packs/one.pack" } ] } };
    [manifest writeToFile:[root stringByAppendingPathComponent:@"OnDemandResources.plist"] atomically:YES];
    NSBundle *made = [NSBundle bundleWithPath:root];
    @try { ((void(*)(id,SEL,double,id))objc_msgSend)(made, setPriority, 0.25, level1);
           P(@"on a bundle with level1: answered"); }
    @catch (NSException *e) { P(@"on a bundle with level1: %@: %@", e.name, e.reason); }
    P(@"  and reading it back: %g", ((double(*)(id,SEL,id))objc_msgSend)(made, priorityFor, @"level1"));
    @try { ((void(*)(id,SEL,double,id))objc_msgSend)(made, setPriority, 0.25,
                                                     [NSSet setWithObject:@"level2"]);
           P(@"on a bundle with only level1, for level2: answered"); }
    @catch (NSException *e) { P(@"on a bundle with only level1, for level2: %@: %@", e.name, e.reason); }
} return 0; }
