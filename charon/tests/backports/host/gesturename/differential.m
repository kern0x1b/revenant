#import <UIKit/UIKit.h>
#import <objc/message.h>

void host_attach_prefixed(const char *prefix);

static int failures, checks;

static void compare(NSString *name, NSString *system, NSString *ours)
{
    checks++;
    if ([system isEqual:ours]) {
        printf("ok   %s: %s\n", name.UTF8String, system.UTF8String);
        return;
    }
    failures++;
    printf("FAIL %s: the system answers %s, the backport answers %s\n", name.UTF8String, system.UTF8String, ours.UTF8String);
}

static NSString *ours_name(UIGestureRecognizer *recognizer)
{
    NSString *name = ((id (*)(id, SEL))objc_msgSend)(recognizer, NSSelectorFromString(@"charonHost_name"));
    return name ?: @"(nil)";
}

static void set_ours_name(UIGestureRecognizer *recognizer, NSString *name)
{
    ((void (*)(id, SEL, id))objc_msgSend)(recognizer, NSSelectorFromString(@"charonHost_setName:"), name);
}

int main(void)
{
    @autoreleasepool {
        host_attach_prefixed("");
        UITapGestureRecognizer *system = [UITapGestureRecognizer new];
        UITapGestureRecognizer *ours = [UITapGestureRecognizer new];

        compare(@"the name starts out empty", system.name ?: @"(nil)", ours_name(ours));

        system.name = @"tap";
        set_ours_name(ours, @"tap");
        compare(@"a name that was set comes back", system.name, ours_name(ours));

        NSMutableString *systemMutable = [NSMutableString stringWithString:@"first"];
        NSMutableString *ourMutable = [NSMutableString stringWithString:@"first"];
        system.name = systemMutable;
        set_ours_name(ours, ourMutable);
        [systemMutable appendString:@"-changed"];
        [ourMutable appendString:@"-changed"];
        compare(@"the name is copied, not held", system.name, ours_name(ours));
        compare(@"the copy is a different object",
                system.name == systemMutable ? @"the same" : @"a copy",
                ours_name(ours) == ourMutable ? @"the same" : @"a copy");

        system.name = nil;
        set_ours_name(ours, nil);
        compare(@"clearing the name works", system.name ?: @"(nil)", ours_name(ours));

        UIPanGestureRecognizer *systemPan = [UIPanGestureRecognizer new];
        UIPanGestureRecognizer *ourPan = [UIPanGestureRecognizer new];
        systemPan.name = @"pan";
        set_ours_name(ourPan, @"pan");
        system.name = @"tap";
        set_ours_name(ours, @"tap");
        compare(@"two recognizers keep their own names",
                [NSString stringWithFormat:@"%@/%@", system.name, systemPan.name],
                [NSString stringWithFormat:@"%@/%@", ours_name(ours), ours_name(ourPan)]);

        printf("note the system prints the name in -description (\"%s\"), which the port cannot:\n"
               "     -description belongs to the release and the port does not replace it.\n",
               system.description.UTF8String);
        printf("%d of %d checks failed\n", failures, checks);
        return failures > 0;
    }
}
