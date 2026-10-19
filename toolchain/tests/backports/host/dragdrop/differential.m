#import <UIKit/UIKit.h>
#import <objc/message.h>
#import "check.h"

static Class cls(BOOL ours, NSString *name)
{
    return NSClassFromString(ours ? [@"CharonHost" stringByAppendingString:name] : name);
}

static const char *label(NSString *format, ...)
{
    static NSMutableArray *keep;
    if (!keep)
        keep = [NSMutableArray array];
    va_list arguments;
    va_start(arguments, format);
    NSString *string = [[NSString alloc] initWithFormat:format arguments:arguments];
    va_end(arguments);
    [keep addObject:string];
    return string.UTF8String;
}

@interface Delegate : NSObject <UIDragInteractionDelegate, UIDropInteractionDelegate>
@end
@implementation Delegate
@end

static id proposal(BOOL ours, NSUInteger operation)
{
    return ((id (*)(id, SEL, NSUInteger))objc_msgSend)([cls(ours, @"UIDropProposal") alloc], @selector(initWithDropOperation:), operation);
}

static NSString *describe(id p)
{
    UIDropProposal *proposal = p;
    return [NSString stringWithFormat:@"%lu %d %d", (unsigned long)proposal.operation, proposal.isPrecise, proposal.prefersFullSizePreview];
}

static void proposals(void)
{
    for (NSUInteger operation = 0; operation < 5; operation++) {
        id ours = proposal(YES, operation), system = proposal(NO, operation);
        CHECK_EQUAL(describe(ours), describe(system), label(@"proposal %lu fresh", (unsigned long)operation));
        [ours setPrecise:YES];
        [system setPrecise:YES];
        [ours setPrefersFullSizePreview:NO];
        [system setPrefersFullSizePreview:NO];
        CHECK_EQUAL(describe(ours), describe(system), label(@"proposal %lu set", (unsigned long)operation));
        id ourCopy = [ours copy], systemCopy = [system copy];
        CHECK_EQUAL(describe(ourCopy), describe(systemCopy), label(@"proposal %lu copy", (unsigned long)operation));
        CHECK(ourCopy != ours && systemCopy != system, label(@"proposal %lu copy is new", (unsigned long)operation));
        CHECK_EQUAL(NSStringFromClass([ourCopy class]), @"CharonHostUIDropProposal", label(@"proposal %lu copy class", (unsigned long)operation));
    }
}

static id item(BOOL ours, NSItemProvider *provider)
{
    return ((id (*)(id, SEL, id))objc_msgSend)([cls(ours, @"UIDragItem") alloc], @selector(initWithItemProvider:), provider);
}

static void items(void)
{
    NSItemProvider *provider = [[NSItemProvider alloc] initWithObject:@"text"];
    id ours = item(YES, provider), system = item(NO, provider);
    CHECK([ours itemProvider] == provider && [system itemProvider] == provider, "item provider kept by identity");
    CHECK([ours localObject] == nil && [system localObject] == nil, "item local object starts nil");
    CHECK([ours previewProvider] == nil && [system previewProvider] == nil, "item preview provider starts nil");
    NSObject *local = [NSObject new];
    [ours setLocalObject:local];
    [system setLocalObject:local];
    CHECK([ours localObject] == local && [system localObject] == local, "item local object kept by identity");
    __block int calls = 0;
    UIDragPreview * (^block)(void) = ^UIDragPreview *{ calls++; return nil; };
    [ours setPreviewProvider:block];
    [system setPreviewProvider:block];
    CHECK([ours previewProvider] != nil && [system previewProvider] != nil, "item preview provider kept");
    CHECK([ours previewProvider]() == nil && [system previewProvider]() == nil && calls == 2, "item preview provider callable");
    [ours setPreviewProvider:nil];
    [system setPreviewProvider:nil];
    CHECK([ours previewProvider] == nil && [system previewProvider] == nil, "item preview provider cleared");
    id nilOurs = item(YES, nil), nilSystem = item(NO, nil);
    CHECK(nilOurs != nil && nilSystem != nil && [nilOurs itemProvider] == nil && [nilSystem itemProvider] == nil, "item with no provider");
}

static void interactions(void)
{
    Delegate *delegate = [Delegate new];
    id ourDrag = ((id (*)(id, SEL, id))objc_msgSend)([cls(YES, @"UIDragInteraction") alloc], @selector(initWithDelegate:), delegate);
    id systemDrag = ((id (*)(id, SEL, id))objc_msgSend)([cls(NO, @"UIDragInteraction") alloc], @selector(initWithDelegate:), delegate);
    CHECK([ourDrag delegate] == delegate && [systemDrag delegate] == delegate, "drag delegate kept");
    CHECK([ourDrag allowsSimultaneousRecognitionDuringLift] == [systemDrag allowsSimultaneousRecognitionDuringLift], "drag lift default");
    CHECK([ourDrag view] == nil && [systemDrag view] == nil, "drag view starts nil");
    [ourDrag setEnabled:YES];
    [systemDrag setEnabled:YES];
    CHECK([ourDrag isEnabled] == [systemDrag isEnabled], "drag enabled set YES");
    [ourDrag setEnabled:NO];
    [systemDrag setEnabled:NO];
    CHECK([ourDrag isEnabled] == [systemDrag isEnabled], "drag enabled set NO");
    [ourDrag setAllowsSimultaneousRecognitionDuringLift:YES];
    [systemDrag setAllowsSimultaneousRecognitionDuringLift:YES];
    CHECK([ourDrag allowsSimultaneousRecognitionDuringLift] == [systemDrag allowsSimultaneousRecognitionDuringLift], "drag lift set");
    UIView *ourView = [UIView new], *systemView = [UIView new];
    [ourView addInteraction:ourDrag];
    [systemView addInteraction:systemDrag];
    CHECK([ourDrag view] == ourView && [systemDrag view] == systemView, "drag view after add");
    CHECK([ourView.interactions containsObject:ourDrag], "drag listed by the view");
    [ourView removeInteraction:ourDrag];
    [systemView removeInteraction:systemDrag];
    CHECK([ourDrag view] == nil && [systemDrag view] == nil, "drag view after remove");
    Delegate *gone = [Delegate new];
    id weakOurs = ((id (*)(id, SEL, id))objc_msgSend)([cls(YES, @"UIDragInteraction") alloc], @selector(initWithDelegate:), gone);
    id weakSystem = ((id (*)(id, SEL, id))objc_msgSend)([cls(NO, @"UIDragInteraction") alloc], @selector(initWithDelegate:), gone);
    gone = nil;
    CHECK([weakOurs delegate] == nil && [weakSystem delegate] == nil, "drag delegate is weak");
    id ourDrop = ((id (*)(id, SEL, id))objc_msgSend)([cls(YES, @"UIDropInteraction") alloc], @selector(initWithDelegate:), delegate);
    id systemDrop = ((id (*)(id, SEL, id))objc_msgSend)([cls(NO, @"UIDropInteraction") alloc], @selector(initWithDelegate:), delegate);
    CHECK([ourDrop delegate] == delegate && [systemDrop delegate] == delegate, "drop delegate kept");
    CHECK([ourDrop allowsSimultaneousDropSessions] == [systemDrop allowsSimultaneousDropSessions], "drop sessions default");
    [ourDrop setAllowsSimultaneousDropSessions:YES];
    [systemDrop setAllowsSimultaneousDropSessions:YES];
    CHECK([ourDrop allowsSimultaneousDropSessions] == [systemDrop allowsSimultaneousDropSessions], "drop sessions set");
    UIView *ourDropView = [UIView new], *systemDropView = [UIView new];
    [ourDropView addInteraction:ourDrop];
    [systemDropView addInteraction:systemDrop];
    CHECK([ourDrop view] == ourDropView && [systemDrop view] == systemDropView, "drop view after add");
    [ourDropView removeInteraction:ourDrop];
    [systemDropView removeInteraction:systemDrop];
    CHECK([ourDrop view] == nil && [systemDrop view] == nil, "drop view after remove");
    id weakDrop = ((id (*)(id, SEL, id))objc_msgSend)([cls(YES, @"UIDropInteraction") alloc], @selector(initWithDelegate:), [Delegate new]);
    CHECK([weakDrop delegate] == nil, "drop delegate is weak");
}

static void session(void)
{
    id<UIDropSession> session = [[NSClassFromString(@"CharonHostDragDropSession") alloc] init];
    CHECK(session != nil, "drop session is constructible");
    CHECK([session canLoadObjectsOfClass:[NSString class]] == NO, "drop session canLoadObjectsOfClass answers NO");
    __block BOOL called = NO;
    __block NSArray *loaded = nil;
    NSProgress *progress = [session loadObjectsOfClass:[NSString class] completion:^(NSArray<__kindof id<NSItemProviderReading>> *objects) {
        called = YES;
        loaded = objects;
    }];
    CHECK(called && loaded != nil && loaded.count == 0, "drop session loadObjectsOfClass:completion: answers an empty array");
    CHECK(progress != nil && progress.completedUnitCount == progress.totalUnitCount, "drop session load returns a finished progress");
}

int main(void)
{
    @autoreleasepool {
        proposals();
        items();
        interactions();
        session();
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    }
    return charon_failures ? 1 : 0;
}
