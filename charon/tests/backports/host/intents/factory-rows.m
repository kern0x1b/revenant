// factory-rows.m: the six release-13 rows of registry/Intents/ios16.json that the file listed as
// absent with a reason about a group of the delivery, measured against the system's own class.
//
// WHY objc_msgSend AND NOT THE IMP.  An earlier version of this harness called each method through
// class_getMethodImplementation and every one of the four classes killed the process with
// EXC_ARM_DA_ALIGN at the IMP address (crash report read back: the symbol is
// _OBJC_$_CLASS_METHODS_INFile(Readable|INEnumerable|INJSONSerialization), so this host's Intents
// compiles its Objective-C entry points as SVE/pointer-authenticated thunks and a bare C function
// pointer reaches them on the wrong convention).  objc_msgSend is the runtime's own entry point and
// dispatches on the real convention, so every call below goes through it.  This is worth writing
// down: the first harness did not read "the class is absent", it read "the reader is wrong", and
// only the crash reports told the two apart.
//
// WHY NOTHING HERE NAMES A CLASS THE SDK HIDES.  All four are API_UNAVAILABLE(macos) in the SDK, so
// a variable of the class's own type does not compile in this program.  Every value is read through
// KVC on an id and every method is reached by selector from the runtime.
//
// ONE SECTION PER RUN, and the section is an argument, so that a section which cannot be answered
// cannot take the other three down with it.  A single process running all four would have died in
// the first - which is exactly what happened - and printed nothing about the rest.
//
//   $ xcrun clang -fobjc-arc -w -framework Intents -framework Foundation \
//         tests/backports/host/intents/factory-rows.m -o factory-rows
//   $ ./factory-rows destination     # also: resolution, file, usercontext
#import <Foundation/Foundation.h>
#import <Intents/Intents.h>
#import <objc/message.h>
#import <objc/runtime.h>

// One wrapper per arity, so each call names its own signature.  A single variadic helper forwarding
// a va_list would be shorter and wrong: a va_list is not a set of arguments.
static id send_none(id receiver, SEL selector)
{
    return ((id (*)(id, SEL))objc_msgSend)(receiver, selector);
}

static id send_one(id receiver, SEL selector, id first)
{
    return ((id (*)(id, SEL, id))objc_msgSend)(receiver, selector, first);
}

static id send_one_integer(id receiver, SEL selector, id first, NSInteger second)
{
    return ((id (*)(id, SEL, id, NSInteger))objc_msgSend)(receiver, selector, first, second);
}

static id send_two(id receiver, SEL selector, id first, id second)
{
    return ((id (*)(id, SEL, id, id))objc_msgSend)(receiver, selector, first, second);
}

static id send_three(id receiver, SEL selector, id first, id second, id third)
{
    return ((id (*)(id, SEL, id, id, id))objc_msgSend)(receiver, selector, first, second, third);
}

static NSString *shown(id value)
{
    return value ? [value description] : @"nil";
}

#define text(value) (shown(value).UTF8String)

// An enumeration-valued property, read through KVC, because the class is unavailable to this SDK
// and its own type cannot be named here.
static long long enumeration(id object, NSString *name)
{
    return (long long)[[object valueForKey:name] longLongValue];
}

static NSArray<NSString *> *property_names(Class cls)
{
    unsigned count = 0;
    objc_property_t *properties = class_copyPropertyList(cls, &count);
    NSMutableArray<NSString *> *names = [NSMutableArray array];
    for (unsigned index = 0; index < count; index++) {
        [names addObject:[NSString stringWithUTF8String:property_getName(properties[index])]];
    }
    free(properties);
    return names;
}

int main(int argc, char **argv)
{
    setvbuf(stdout, NULL, _IOLBF, 0);
    NSString *section = argc > 1 ? [NSString stringWithUTF8String:argv[1]] : @"all";
    @autoreleasepool {
        printf("section %s\n", section.UTF8String);
        // The control: a class the system does not carry has to read ABSENT, or a run that measures
        // nothing is indistinguishable from a run that measures an absence.  This harness learned
        // that the hard way - see the note above objc_msgSend.
        printf("control: INCharonNoSuchClassForThisHarness reads %s\n",
               NSClassFromString(@"INCharonNoSuchClassForThisHarness") ? "PRESENT, which is wrong"
                                                                        : "absent, as it must");
        BOOL all = [section isEqualToString:@"all"];

        // ---- +[INMediaDestination libraryDestination] and +playlistDestinationWithName: ----
        if (all || [section isEqualToString:@"destination"]) {
            printf("\n== +[INMediaDestination libraryDestination] / +playlistDestinationWithName: ==\n");
            Class cls = NSClassFromString(@"INMediaDestination");
            printf("  the class reads %s, %lu properties of its own (%s)\n", cls ? "present" : "ABSENT",
                   (unsigned long)property_names(cls).count,
                   text([property_names(cls) componentsJoinedByString:@" "]));
            if (cls) {
                id library = send_none((id)cls, @selector(libraryDestination));
                id playlist = send_one((id)cls, @selector(playlistDestinationWithName:), @"Charon Probe");
                id again = send_none((id)cls, @selector(libraryDestination));
                id empty = send_one((id)cls, @selector(playlistDestinationWithName:), nil);
                printf("  libraryDestination                    -> mediaDestinationType %lld  playlistName %s\n",
                       enumeration(library, @"mediaDestinationType"),
                       text([library valueForKey:@"playlistName"]));
                printf("  playlistDestinationWithName:CharonProbe -> mediaDestinationType %lld  playlistName %s\n",
                       enumeration(playlist, @"mediaDestinationType"),
                       text([playlist valueForKey:@"playlistName"]));
                printf("  a second libraryDestination          -> mediaDestinationType %lld  playlistName %s  isEqual the first %d\n",
                       enumeration(again, @"mediaDestinationType"), text([again valueForKey:@"playlistName"]),
                       (int)[library isEqual:again]);
                printf("  playlistDestinationWithName:nil      -> mediaDestinationType %lld  playlistName %s\n",
                       enumeration(empty, @"mediaDestinationType"), text([empty valueForKey:@"playlistName"]));
                printf("  INMediaDestinationType.h: Unknown=0 Library=1 Playlist=2\n");
            }
        }

        // ---- +[INAddTasksTargetTaskListResolutionResult confirmationRequired...forReason:] ----
        // Its superclass already carries the one-argument factory, so what the subclass's answer adds
        // is the question.  Its description is the whole of what the class can be inspected for: the
        // class declares no property of its own, so a reason kept anywhere would be kept nowhere the
        // SDK declares.
        if (all || [section isEqualToString:@"resolution"]) {
            printf("\n== +[INAddTasksTargetTaskListResolutionResult confirmationRequiredWithTaskListToConfirm:forReason:] ==\n");
            Class cls = NSClassFromString(@"INAddTasksTargetTaskListResolutionResult");
            Class parent = NSClassFromString(@"INTaskListResolutionResult");
            printf("  the class reads %s, superclass %s, %lu properties of its own (%s)\n",
                   cls ? "present" : "ABSENT", class_getName(class_getSuperclass(cls)),
                   (unsigned long)property_names(cls).count,
                   text([property_names(cls) componentsJoinedByString:@" "]));
            if (cls && parent) {
                id withReason = send_one_integer((id)cls,
                                                 @selector(confirmationRequiredWithTaskListToConfirm:forReason:),
                                                 nil, (NSInteger)1);
                id plain = send_one((id)parent, @selector(confirmationRequiredWithTaskListToConfirm:), nil);
                printf("  forReason:INAddTasksTargetTaskListConfirmationReasonListShouldBeCreated, nil list\n");
                printf("            an object of class %s, described:\n", class_getName([withReason class]));
                printf("%s\n", text(withReason));
                printf("  the superclass's own one-argument factory, nil list\n");
                printf("            an object of class %s, described:\n", class_getName([plain class]));
                printf("%s\n", text(plain));
                printf("  the reason is in no property either class declares, so it is kept where only this\n"
                       "  port can read it - the same answer +unsupportedForReason: already gives\n");
            }
        }

        // ---- +[INFile fileWithData:...] and +fileWithFileURL:...] ----
        // INFile is the one class of the four this SDK does declare on macOS, and the two factories are
        // the only rows of the six the header's own words fully determine: a filename of nil is the
        // header's own nullable, and the URL form is the one that reads the file.
        if (all || [section isEqualToString:@"file"]) {
            printf("\n== +[INFile fileWithData:filename:typeIdentifier:] / +fileWithFileURL:filename:typeIdentifier:] ==\n");
            Class cls = NSClassFromString(@"INFile");
            printf("  the class reads %s\n", cls ? "present" : "ABSENT");
            if (cls) {
                NSData *bytes = [@"charon" dataUsingEncoding:NSUTF8StringEncoding];
                NSURL *url = [NSURL fileURLWithPath:@"/etc/hosts"];
                id memory = send_three((id)cls, @selector(fileWithData:filename:typeIdentifier:), bytes,
                                       @"probe.txt", @"public.plain-text");
                id unnamed = send_three((id)cls, @selector(fileWithData:filename:typeIdentifier:), bytes,
                                        nil, nil);
                id onDisk = send_three((id)cls, @selector(fileWithFileURL:filename:typeIdentifier:), url,
                                       nil, nil);
                id namedOnDisk = send_three((id)cls, @selector(fileWithFileURL:filename:typeIdentifier:), url,
                                            @"given.txt", @"public.plain-text");
                id absent = send_three((id)cls, @selector(fileWithFileURL:filename:typeIdentifier:),
                                       [NSURL fileURLWithPath:@"/etc/hosts/charon-probe"], nil, nil);
                printf("  fileWithData(\"charon\", \"probe.txt\", \"public.plain-text\")\n");
                printf("            data %s  filename %s  typeIdentifier %s  fileURL %s  removedOnCompletion %lld\n",
                       text([memory valueForKey:@"data"]), text([memory valueForKey:@"filename"]),
                       text([memory valueForKey:@"typeIdentifier"]), text([memory valueForKey:@"fileURL"]),
                       enumeration(memory, @"removedOnCompletion"));
                printf("            data is the very NSData it was given %d\n",
                       (int)([memory valueForKey:@"data"] == bytes));
                printf("  fileWithData(\"charon\", nil, nil)   -> filename %s  typeIdentifier %s\n",
                       text([unnamed valueForKey:@"filename"]), text([unnamed valueForKey:@"typeIdentifier"]));
                printf("  fileWithFileURL(/etc/hosts, nil, nil)\n");
                printf("            filename %s  fileURL %s  typeIdentifier %s  data %lu bytes  removedOnCompletion %lld\n",
                       text([onDisk valueForKey:@"filename"]), text([onDisk valueForKey:@"fileURL"]),
                       text([onDisk valueForKey:@"typeIdentifier"]),
                       (unsigned long)[[onDisk valueForKey:@"data"] length],
                       enumeration(onDisk, @"removedOnCompletion"));
                printf("  fileWithFileURL(/etc/hosts, \"given.txt\", \"public.plain-text\")\n");
                printf("            filename %s  fileURL %s  typeIdentifier %s\n",
                       text([namedOnDisk valueForKey:@"filename"]),
                       text([namedOnDisk valueForKey:@"fileURL"]),
                       text([namedOnDisk valueForKey:@"typeIdentifier"]));
                printf("  fileWithFileURL(/etc/hosts/charon-probe, nil, nil) - a path that does not exist\n");
                printf("            filename %s  data %lu bytes\n",
                       text([absent valueForKey:@"filename"]),
                       (unsigned long)[[absent valueForKey:@"data"] length]);
                printf("  /etc/hosts is %lu bytes on this machine, which is what the URL form read\n",
                       (unsigned long)[[NSData dataWithContentsOfFile:@"/etc/hosts"] length]);
            }
        }

        // ---- -[INUserContext becomeCurrent] ----
        // The base class declares no -init and no property of its own (measured): it is a token, its
        // identity is its class, and what the method does is hand it to a store.  A subclass is the
        // object the method is written for - INMediaUserContext is the one this SDK declares - and it
        // is made through the class's own _init, because -init is NSObject's here.
        if (all || [section isEqualToString:@"usercontext"]) {
            printf("\n== -[INUserContext becomeCurrent] ==\n");
            Class cls = NSClassFromString(@"INUserContext");
            Class subclass = NSClassFromString(@"INMediaUserContext");
            printf("  the class reads %s, superclass %s, %lu properties of its own (%s)\n",
                   cls ? "present" : "ABSENT", class_getName(class_getSuperclass(cls)),
                   (unsigned long)property_names(cls).count,
                   text([property_names(cls) componentsJoinedByString:@" "]));
            unsigned methods = 0;
            Method *list = class_copyMethodList(cls, &methods);
            printf("  the methods it declares itself:");
            for (unsigned index = 0; index < methods; index++) {
                printf(" %s", sel_getName(method_getName(list[index])));
            }
            free(list);
            printf("\n  (no -init among them, so -[INUserContext init] is NSObject's)\n");
            if (subclass) {
                printf("  the one subclass this SDK declares is %s, with %lu properties (%s)\n",
                       class_getName(subclass), (unsigned long)property_names(subclass).count,
                       text([property_names(subclass) componentsJoinedByString:@" "]));
                id made = send_none(send_none((id)subclass, @selector(alloc)), @selector(_init));
                printf("  the object the method is written for: %s, subscriptionStatus %lld, numberOfLibraryItems %s\n",
                       made ? "an object" : "nil", enumeration(made, @"subscriptionStatus"),
                       text([made valueForKey:@"numberOfLibraryItems"]));
                ((void (*)(id, SEL))objc_msgSend)(made, @selector(becomeCurrent));
                printf("  -becomeCurrent returned with no exception\n");
                printf("  and the class declares no reader of its own, so what it made current is read by\n"
                       "  nothing the SDK declares - the assistant's user-context store is the reader\n");
            }
        }
        return 0;
    }
}