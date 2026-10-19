// init-rows.m: the -[X init] rows whose header marks -init unavailable, class by class, against the
// system's own class of the same name.  The per-class harness facts/Intents/Intents.md names as owed.
//
// WHY A HARNESS AND NOT A TABLE.  facts/Intents/Intents.md carried eight classes measured by hand
// and said the other hundred and two were "the same rule applied to the same header, which is a
// claim and not a measurement until a harness runs them".  This is that harness, for the classes of
// one slice, and facts/Intents/Intents.md names it.
//
// WHAT IT ANSWERS, PER CLASS:
//
//   class_getMethodImplementation(Cls, @selector(init))   non-NULL
//   [[Cls alloc] init] THROUGH THAT IMP                   an object, with no exception
//   respondsToSelector:init                                1
//   every property the class's own header declares        what it answers after that -init
//
// THROUGH THAT IMP and not through a send, because the header forbids naming the selector at compile
// time - the same constraint the port's own emitted body is built around, so the harness reads the
// port the way the port reads itself.
//
// WHICH PROPERTIES, AND WHY IT IS A FILTER AND NOT A WALK.  class_copyPropertyList answers MORE than
// the class declares: on the host it also answers NSObject's six (hash, superclass, description,
// debugDescription, class, zone), and every property whose name begins with an underscore - the ones
// Apple's own ivars are reached through, _success, _code, backingStore, _stage and thirty more on
// INStartCallIntentResponse alone.  Neither is a property the SDK's header declares, so neither is
// this row's business: a check that asked NSObject's hash for nil would fail on a class that answers
// perfectly, and a check that read _success through KVC would raise on a class that answers
// perfectly.  The count of what the filter dropped is printed on every run, so the filter is
// visible and not a silent narrowing.
//
// "NOTHING TO SAY" IS NOT "nil", AND THE HARNESS SAYS WHICH.  A property of object type reads nil.
// A property of an enumeration type reads an NSNumber, and it reads 0 - the enumeration's own zero
// case - because that is what zeroed integer storage holds.  The framework says itself that this is
// the same thing: gen-intents.py's NEUTRAL_ENUMERATIONS is the host's own list of the enumerations
// whose zero case "will be reformed to notRequired", a success with nothing to say.  So the harness
// prints 0 as "the zero case" and the row quotes that, instead of a nil that never happens.
//
// THE CONTROL IS THE POINT, and it is in every run.  A class the system does not carry must read
// ABSENT, or a run that "passes" because it measured nothing is indistinguishable from a run that
// passes because the system answers.  NSObject is asked in the same run and must answer: it is a
// class whose -init the SDK does not mark unavailable, so it is the shape a real answer looks like.
// A class list naming a class the system does not carry must be reported as a failure, and
// run-rows.sh runs that list too, so a harness that could not tell the two apart would be caught.
//
//   $ xcrun clang -fobjc-arc -w -framework Intents -framework Foundation \
//         tests/backports/host/intents/init-rows.m -o init-rows
//   $ ./init-rows init-classes.txt
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

// NSObject's own six, which every class carries and no Intents header declares.
static NSSet<NSString *> *NSObject_properties(void)
{
    static NSSet *names = nil;
    if (names == nil) {
        names = [NSSet setWithArray:@[@"hash", @"superclass", @"description", @"debugDescription",
                                     @"class", @"zone", @"self", @"isProxy"]];
    }
    return names;
}

// What the SDK's own header declares for the class: every property of the class and of the Intents
// superclasses above it whose name is not one of NSObject's and does not begin with an underscore.
static NSArray<NSString *> *declared_properties(Class cls)
{
    NSMutableArray<NSString *> *names = [NSMutableArray array];
    NSMutableSet<NSString *> *seen = [NSMutableSet set];
    for (Class level = cls; level != Nil && level != [NSObject class]; level = class_getSuperclass(level)) {
        unsigned count = 0;
        objc_property_t *properties = class_copyPropertyList(level, &count);
        for (unsigned index = 0; index < count; index++) {
            NSString *name = [NSString stringWithUTF8String:property_getName(properties[index])];
            if ([name hasPrefix:@"_"] || [NSObject_properties() containsObject:name] || [seen containsObject:name]) {
                continue;
            }
            [seen addObject:name];
            [names addObject:name];
        }
        free(properties);
    }
    return names;
}

static NSString *read_property(id object, NSString *name, NSString **thrown)
{
    id value = nil;
    @try {
        value = [object valueForKey:name];
    } @catch (NSException *exception) {
        if (*thrown == nil) {
            *thrown = [NSString stringWithFormat:@"threw %@ reading %@", exception.name, name];
        }
        return [NSString stringWithFormat:@"%@ UNREADABLE", name];
    }
    if (value == nil) {
        return [NSString stringWithFormat:@"%@ nil", name];
    }
    if ([value isKindOfClass:[NSNumber class]]) {
        long long number = [value longLongValue];
        return number == 0 ? [NSString stringWithFormat:@"%@ the zero case", name]
                           : [NSString stringWithFormat:@"%@ %lld", name, number];
    }
    return [NSString stringWithFormat:@"%@ %@", name, value];
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        NSString *list = [[NSProcessInfo processInfo] arguments][1];
        NSString *text = [NSString stringWithContentsOfFile:list encoding:NSUTF8StringEncoding error:NULL];
        if (text == nil) {
            fprintf(stderr, "init-rows: the class list %s could not be read\n", list.UTF8String);
            return 2;
        }
        NSMutableArray<NSString *> *classes = [NSMutableArray array];
        for (NSString *line in [text componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]) {
            NSString *name = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            if (name.length > 0 && ![name hasPrefix:@"#"]) {
                [classes addObject:name];
            }
        }

        printf("control: INCharonNoSuchClassForThisHarness reads %s\n",
               NSClassFromString(@"INCharonNoSuchClassForThisHarness") ? "PRESENT, which is wrong"
                                                                        : "absent, as it must");
        IMP plain = class_getMethodImplementation([NSObject class], @selector(init));
        id plainObject = plain ? ((id (*)(id, SEL))plain)([NSObject class], @selector(init)) : nil;
        printf("control: NSObject, whose -init the SDK does not mark unavailable, has IMP %s and %s through it\n",
               plain ? "non-NULL" : "NULL",
               plain ? (plainObject ? "answers an object" : "answers nil") : "is not called");
        Class airline = NSClassFromString(@"INAirline");
        unsigned carried = 0;
        objc_property_t *raw = class_copyPropertyList(airline, &carried);
        free(raw);
        printf("control: INAirline declares %lu of its own, %lu of the %u class_copyPropertyList answers\n",
               (unsigned long)declared_properties(airline).count, (unsigned long)declared_properties(airline).count,
               carried);

        NSUInteger green = 0, red = 0;
        for (NSString *name in classes) {
            Class cls = NSClassFromString(name);
            if (cls == nil) {
                printf("%-40s ABSENT: the system carries no such class, so nothing answers the row\n",
                       name.UTF8String);
                red++;
                continue;
            }
            IMP forward = class_getMethodImplementation(cls, @selector(init));
            id object = nil;
            NSString *thrown = nil;
            if (forward != NULL) {
                @try {
                    object = ((id (*)(id, SEL))forward)([cls alloc], @selector(init));
                } @catch (NSException *exception) {
                    thrown = [NSString stringWithFormat:@"threw %@: %@", exception.name, exception.reason];
                }
            }
            NSMutableArray<NSString *> *values = [NSMutableArray array];
            NSArray<NSString *> *properties = declared_properties(cls);
            for (NSString *property in properties) {
                [values addObject:read_property(object, property, &thrown)];
            }
            BOOL answersInit = [object respondsToSelector:@selector(init)];
            BOOL ok = forward != NULL && object != nil && thrown == nil && answersInit;
            ok ? green++ : red++;
            printf("%-40s IMP %-8s object %-3s rTS %d  %s\n", name.UTF8String,
                   forward ? "non-NULL" : "NULL", object ? "yes" : "NO", (int)answersInit,
                   ok ? "PASS" : "FAIL");
            for (NSString *value in values) {
                printf("            %s\n", value.UTF8String);
            }
            if (thrown) {
                printf("            %s\n", thrown.UTF8String);
            }
        }
        printf("init-rows: %lu answer -init with an object, %lu do not\n", (unsigned long)green,
               (unsigned long)red);
        return red == 0 ? 0 : 1;
    }
}