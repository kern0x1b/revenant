#import <Foundation/Foundation.h>
#import <Intents/Intents.h>
#import <objc/message.h>
#import <objc/runtime.h>

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
        printf("control: INCharonNoSuchClassForThisHarness reads %s\n",
               NSClassFromString(@"INCharonNoSuchClassForThisHarness") ? "PRESENT, which is wrong"
                                                                        : "absent, as it must");
        BOOL all = [section isEqualToString:@"all"];

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
