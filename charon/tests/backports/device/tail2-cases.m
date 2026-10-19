#import "tail2-cases.h"

void tail2_run(Tail2Recorder record)
{
    NSExtensionContext *context = [[NSExtensionContext alloc] init];
    record(@"input items", [NSString stringWithFormat:@"%lu %d", (unsigned long)context.inputItems.count, [context.inputItems isKindOfClass:[NSArray class]]]);
    __block int called = 0;
    [context completeRequestReturningItems:nil completionHandler:^(BOOL expired) { called++; }];
    [context cancelRequestWithError:[NSError errorWithDomain:@"charon.extension" code:1 userInfo:nil]];
    [context openURL:[NSURL URLWithString:@"http://example.com"] completionHandler:^(BOOL success) { called++; }];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.3]];
    record(@"a context with no host does nothing", [NSString stringWithFormat:@"%d", called]);
    UIViewController *controller = [[UIViewController alloc] init];
    UIViewController *child = [[UIViewController alloc] init];
    [controller addChildViewController:child];
    record(@"a controller in an application has none", [NSString stringWithFormat:@"%d %d", controller.extensionContext == nil, child.extensionContext == nil]);
    record(@"constants", [@[NSExtensionItemsAndErrorsKey, NSExtensionHostWillEnterForegroundNotification, NSExtensionHostDidEnterBackgroundNotification, NSExtensionHostWillResignActiveNotification, NSExtensionHostDidBecomeActiveNotification] componentsJoinedByString:@","]);
    record(@"a class of its own", [NSString stringWithFormat:@"%d %d", [context isKindOfClass:[NSObject class]], [NSExtensionContext instancesRespondToSelector:@selector(inputItems)]]);
    record(@"pasteboard option keys", [@[UIPasteboardOptionExpirationDate, UIPasteboardOptionLocalOnly] componentsJoinedByString:@","]);
}
