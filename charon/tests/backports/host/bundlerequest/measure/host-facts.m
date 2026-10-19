// bundle-resource-request-facts.m - what the host's own NSBundleResourceRequest answers, step by step.
// Every number this prints is a value the port has to reproduce.
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <dlfcn.h>

/* -loadingPriority is a double, so it is read through an invocation like every other member: the
   release's own header does not declare this class and the SDK's is behind an availability. */
static double charon_priority(id object)
{
    SEL selector = NSSelectorFromString(@"loadingPriority");
    if (![object respondsToSelector:selector])
        return -1;
    NSMethodSignature *signature = [object methodSignatureForSelector:selector];
    NSInvocation *call = [NSInvocation invocationWithMethodSignature:signature];
    call.selector = selector;
    call.target = object;
    [call invoke];
    double value = -1;
    [call getReturnValue:&value];
    return value;
}

static void P(NSString *f, ...) NS_FORMAT_FUNCTION(1, 2);
static void P(NSString *f, ...)
{
    va_list a;
    va_start(a, f);
    NSString *s = [[NSString alloc] initWithFormat:f arguments:a];
    va_end(a);
    printf("%s\n", s.UTF8String);
}

@interface CharonKeys : NSKeyedUnarchiver
@end

@implementation CharonKeys
- (id)decodeObjectOfClass:(Class)cls forKey:(NSString *)key
{
    id value = [super decodeObjectOfClass:cls forKey:key];
    P(@"  key %-28s -> %@", [key UTF8String], value);
    return value;
}
- (NSInteger)decodeIntegerForKey:(NSString *)key
{
    NSInteger value = [super decodeIntegerForKey:key];
    P(@"  key %-28s -> %ld", [key UTF8String], (long)value);
    return value;
}
- (double)decodeDoubleForKey:(NSString *)key
{
    double value = [super decodeDoubleForKey:key];
    P(@"  key %-28s -> %g", [key UTF8String], value);
    return value;
}
@end

int main(int argc, char **argv)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    @autoreleasepool {
        int step = argc > 1 ? atoi(argv[1]) : 0;
        Class request = NSClassFromString(@"NSBundleResourceRequest");

        if (step == 0) {  // the class, the keys and the constant
            P(@"class %s", request ? class_getName(request) : "(no class)");
            P(@"  super %s", request ? class_getName(class_getSuperclass(request)) : "(no class)");
            P(@"  +alloc gives %s", request ? class_getName([request alloc]) : "(no class)");
            P(@"conforms to: NSProgressReporting=%d NSCopying=%d NSSecureCoding=%d",
              [request conformsToProtocol:@protocol(NSProgressReporting)], (int)[request instancesRespondToSelector:@selector(copyWithZone:)],
              (int)[request instancesRespondToSelector:@selector(supportsSecureCoding)]);
            double urgent = 0;
            void *urgentSymbol = dlsym(RTLD_DEFAULT, "_NSBundleResourceRequestLoadingPriorityUrgent");
            if (urgentSymbol)
                urgent = *(double *)urgentSymbol;
            P(@"NSBundleResourceRequestLoadingPriorityUrgent = %g (dlsym %s)", urgent, urgentSymbol ? "found" : "no symbol");
            void *noteSymbol = dlsym(RTLD_DEFAULT, "_NSBundleResourceRequestLowDiskSpaceNotification");
            id note = nil;
            if (noteSymbol)
                note = *(__unsafe_unretained id *)noteSymbol;
            P(@"NSBundleResourceRequestLowDiskSpaceNotification = |%s| (dlsym %s)", [[note description] UTF8String],
              noteSymbol ? "found" : "no symbol");
            P(@"its class is %s", class_getName([note class]));
            SEL const members[] = { @selector(init), @selector(initWithTags:), @selector(initWithTags:bundle:),
                                     @selector(beginAccessingResourcesWithCompletionHandler:),
                                     @selector(conditionallyBeginAccessingResourcesWithCompletionHandler:),
                                     @selector(endAccessingResources), @selector(tags), @selector(bundle),
                                     @selector(loadingPriority), @selector(setLoadingPriority:), @selector(progress) };
            for (unsigned i = 0; i < sizeof(members) / sizeof(*members); i++)
                P(@"  -%@ %s", sel_getName(members[i]),
                  [request instancesRespondToSelector:members[i]] ? "answers" : "NO");
            return 0;
        }

        if (step == 1) {  // the initialisers and the four properties
            NSSet *tags = [NSSet setWithObjects:@"one", @"two", nil];
            id bare = [[request alloc] init];
            P(@"-init          -> %s", bare ? class_getName([bare class]) : "(nil)");
            if (bare) {
                P(@"  tags=%s bundle=%s priority=%g progress=%s", [[(id)[bare tags] description] UTF8String],
                  [[(id)[bare bundle] description] UTF8String], charon_priority(bare),
                  [[(id)[bare progress] description] UTF8String]);
                P(@"  describes |%@|", [bare description]);
                P(@"  isEqual to a second -init: %d",
                  (int)[bare isEqual:[[[request alloc] init] performSelector:@selector(self)]]);
            }
            id withTags = [request alloc];
            withTags = ((id (*)(id, SEL, id))objc_msgSend)(withTags, @selector(initWithTags:), tags);
            P(@"-initWithTags: -> %s", withTags ? class_getName([withTags class]) : "(nil)");
            if (withTags) {
                P(@"  tags=%s bundle=%s priority=%g", [[(id)[withTags tags] description] UTF8String],
                  [[(id)[withTags bundle] description] UTF8String], charon_priority(withTags));
                id givenTags = (id)[withTags tags];
                P(@"  the tags are the set the caller gave: %d", (int)(givenTags == tags));
                P(@"  progress is %s", [[(id)[withTags progress] description] UTF8String]);
                P(@"  describes |%@|", [withTags description]);
            }
            id withBoth = [request alloc];
            withBoth = ((id (*)(id, SEL, id, id))objc_msgSend)(withBoth, @selector(initWithTags:bundle:), tags, [NSBundle mainBundle]);
            P(@"-initWithTags:bundle: -> %s", withBoth ? class_getName([withBoth class]) : "(nil)");
            if (withBoth) {
                P(@"  tags=%s bundle=%s", [[(id)[withBoth tags] description] UTF8String],
                  [[(id)[withBoth bundle] description] UTF8String]);
                id givenBundle = (id)[withBoth bundle];
                P(@"  the bundle is the one the caller gave: %d", (int)(givenBundle == [NSBundle mainBundle]));
                P(@"  progress is another object against the other: %d", (int)((id)[withBoth progress] != (id)[withTags progress]));
                P(@"  isEqual to the tags-only one: %d", (int)[withBoth isEqual:withTags]);
            }
            P(@"@try -initWithTags: with nil");
            @try {
                id nilTags = [request alloc];
                nilTags = ((id (*)(id, SEL, id))objc_msgSend)(nilTags, @selector(initWithTags:), nil);
                P(@"  -> %s tags=%s", nilTags ? class_getName([nilTags class]) : "(nil)",
                  [[(id)[nilTags tags] description] UTF8String]);
            } @catch (NSException *exception) {
                P(@"  %@: %@", exception.name, exception.reason);
            }
            P(@"@try -initWithTags: with an empty set");
            @try {
                id empty = [request alloc];
                empty = ((id (*)(id, SEL, id))objc_msgSend)(empty, @selector(initWithTags:), [NSSet set]);
                P(@"  -> %s tags=%s", empty ? class_getName([empty class]) : "(nil)", [[(id)[empty tags] description] UTF8String]);
            } @catch (NSException *exception) {
                P(@"  %@: %@", exception.name, exception.reason);
            }
            return 0;
        }

        if (step == 2) {  // the priority, the copy, the equality
            NSSet *tags = [NSSet setWithObjects:@"one", nil];
            id one = [request alloc];
            one = ((id (*)(id, SEL, id))objc_msgSend)(one, @selector(initWithTags:), tags);
            id two = [request alloc];
            two = ((id (*)(id, SEL, id))objc_msgSend)(two, @selector(initWithTags:), tags);
            for (double value = -1; value <= 2; value += 0.25) {
                [(id)one setValue:@(value) forKey:@"loadingPriority"];
                P(@"  priority %6g -> reads %g", value, charon_priority(one));
            }
            [(id)one setValue:@"high" forKey:@"loadingPriority"];
            P(@"  a string through the key reads back: %g", charon_priority(one));
            id copy = [(id)one copy];
            P(@"copy: %s tags=%s priority=%g isEqual=%d same object=%d", copy ? class_getName([copy class]) : "(nil)",
              [[(id)[copy tags] description] UTF8String], charon_priority(copy), (int)[copy isEqual:one],
              (int)(copy == one));
                id copiedTags = (id)[copy tags];
                id originalTags = (id)[one tags];
                P(@"  the copy tags are the set of the original: %d", (int)(copiedTags == originalTags));
                id copiedProgress = (id)[copy progress];
                id originalProgress = (id)[one progress];
                P(@"  the copy progress is another object: %d", (int)(copiedProgress != originalProgress));
            P(@"  one == two: %d, hash %lu vs %lu", (int)[one isEqual:two], (unsigned long)[one hash],
              (unsigned long)[two hash]);
            return 0;
        }

        if (step == 3) {  // the three resource methods, which touch the system
            NSSet *tags = [NSSet setWithObjects:@"one", nil];
            id one = [request alloc];
            one = ((id (*)(id, SEL, id))objc_msgSend)(one, @selector(initWithTags:), tags);
            id before = (id)[one progress];
            P(@"progress before: total=%lld completed=%lld", (long long)[before totalUnitCount], (long long)[before completedUnitCount]);
            __block BOOL called = NO;
            ((void (*)(id, SEL, id))objc_msgSend)(one, @selector(beginAccessingResourcesWithCompletionHandler:),
                                                  ^(NSError *error) {
                called = YES;
                P(@"  begin's handler: error=%s", error ? [[error localizedDescription] UTF8String] : "(nil)");
                if (error)
                    P(@"    domain=%s code=%ld", [[error domain] UTF8String], (long)[error code]);
            });
            P(@"begin returned synchronously, called=%d", (int)called);
            NSDate *until = [NSDate dateWithTimeIntervalSinceNow:2];
            while (!called && [until timeIntervalSinceNow] > 0)
                [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
            P(@"after waiting: called=%d", (int)called);
            id after = (id)[one progress];
            P(@"progress after: total=%lld completed=%lld fraction=%g", (long long)[after totalUnitCount],
              (long long)[after completedUnitCount], [after fractionCompleted]);
            ((void (*)(id, SEL))objc_msgSend)(one, @selector(endAccessingResources));
            P(@"endAccessingResources answered");
            __block BOOL conditionally = NO;
            ((void (*)(id, SEL, id))objc_msgSend)(one, @selector(conditionallyBeginAccessingResourcesWithCompletionHandler:),
                                                  ^(BOOL available) {
                conditionally = YES;
                P(@"  conditionally's handler: %d", (int)available);
            });
            P(@"conditionally returned synchronously, called=%d", (int)conditionally);
            until = [NSDate dateWithTimeIntervalSinceNow:2];
            while (!conditionally && [until timeIntervalSinceNow] > 0)
                [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
            P(@"after waiting: called=%d", (int)conditionally);
            return 0;
        }

        if (step == 4) {  // the archive, and the setters the header declares as read-only
            NSSet *tags = [NSSet setWithObjects:@"one", @"two", nil];
            id one = [request alloc];
            one = ((id (*)(id, SEL, id, id))objc_msgSend)(one, @selector(initWithTags:bundle:), tags, [NSBundle mainBundle]);
            NSMutableData *d = [NSMutableData data];
            NSKeyedArchiver *a = [[NSKeyedArchiver alloc] initForWritingWithMutableData:d];
            [a encodeObject:one forKey:NSKeyedArchiveRootObjectKey];
            [a finishEncoding];
            P(@"%lu bytes", (unsigned long)d.length);
            CharonKeys *u = [[CharonKeys alloc] initForReadingWithData:d];
            u.requiresSecureCoding = NO;
            id back = [u decodeObjectOfClass:[request class] forKey:NSKeyedArchiveRootObjectKey];
            P(@"  read back: %s", back ? class_getName([back class]) : "(nil)");
            if (back)
                P(@"  tags=%s bundle=%s priority=%g progress=%s isEqual=%d", [[(id)[back tags] description] UTF8String],
                  [[(id)[back bundle] description] UTF8String], charon_priority(back),
                  [[(id)[back progress] description] UTF8String], (int)[back isEqual:one]);
            [u finishDecoding];
            P(@"+supportsSecureCoding=%d", (int)[request supportsSecureCoding]);
            return 0;
        }

        if (step == 5) {  // the two NSBundle additions, which the ledger does not list
            P(@"NSBundle +setPreservationPriority:forTags: %s, -preservationPriorityForTag: %s",
              [NSBundle instancesRespondToSelector:@selector(setPreservationPriority:forTags:)] ? "answers" : "NO",
              [NSBundle instancesRespondToSelector:@selector(preservationPriorityForTag:)] ? "answers" : "NO");
            return 0;
        }
    }
    return 0;
}
