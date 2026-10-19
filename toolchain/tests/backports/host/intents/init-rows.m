#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static NSSet<NSString *> *NSObject_properties(void)
{
    static NSSet *names = nil;
    if (names == nil) {
        names = [NSSet setWithArray:@[@"hash", @"superclass", @"description", @"debugDescription",
                                     @"class", @"zone", @"self", @"isProxy"]];
    }
    return names;
}

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

        printf("control: INRevenantNoSuchClassForThisHarness reads %s\n",
               NSClassFromString(@"INRevenantNoSuchClassForThisHarness") ? "PRESENT, which is wrong"
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
