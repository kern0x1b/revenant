#import "../uikit2/uirest.h"
#import <WebKit/WebKit.h>

static id configuration_made_by_a_program(Class cls)
{
    id allocated = [cls alloc];
    SEL selector = NSSelectorFromString(@"init");
    NSMethodSignature *signature = [allocated methodSignatureForSelector:selector];
    if (signature == nil)
        return nil;
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    invocation.selector = selector;
    [invocation invokeWithTarget:allocated];
    void *made = NULL;
    [invocation getReturnValue:&made];
    return (__bridge id)made;
}

static NSArray *webextension_configuration_scenario(void)
{
    NSMutableArray *lines = [NSMutableArray array];

    WKWebExtensionTabConfiguration *tab = configuration_made_by_a_program(WKWebExtensionTabConfiguration.class);
    [lines addObject:ur_line(@"case tab.class", NSStringFromClass([tab class]))];
    [lines addObject:ur_line(@"case tab.isAnObject", ur_yes(tab != nil))];
    [lines addObject:ur_line(@"case tab.window", tab.window)];
    [lines addObject:ur_line(@"case tab.index", @(tab.index))];
    [lines addObject:ur_line(@"case tab.parentTab", tab.parentTab)];
    [lines addObject:ur_line(@"case tab.url", tab.url)];
    [lines addObject:ur_line(@"case tab.shouldBeActive", ur_yes(tab.shouldBeActive))];
    [lines addObject:ur_line(@"case tab.shouldAddToSelection", ur_yes(tab.shouldAddToSelection))];
    [lines addObject:ur_line(@"case tab.shouldBePinned", ur_yes(tab.shouldBePinned))];
    [lines addObject:ur_line(@"case tab.shouldBeMuted", ur_yes(tab.shouldBeMuted))];
    [lines addObject:ur_line(@"case tab.shouldReaderModeBeActive", ur_yes(tab.shouldReaderModeBeActive))];

    WKWebExtensionWindowConfiguration *window = configuration_made_by_a_program(WKWebExtensionWindowConfiguration.class);
    [lines addObject:ur_line(@"case window.class", NSStringFromClass([window class]))];
    [lines addObject:ur_line(@"case window.isAnObject", ur_yes(window != nil))];
    [lines addObject:ur_line(@"case window.windowType", @(window.windowType))];
    [lines addObject:ur_line(@"case window.windowState", @(window.windowState))];
    [lines addObject:ur_line(@"case window.frame", [NSString stringWithFormat:@"%g %g %g %g",
                                                      window.frame.origin.x, window.frame.origin.y,
                                                      window.frame.size.width, window.frame.size.height])];
    [lines addObject:ur_line(@"case window.tabURLsIsNil", ur_yes(window.tabURLs == nil))];
    [lines addObject:ur_line(@"case window.tabURLs.count", @(window.tabURLs.count))];
    [lines addObject:ur_line(@"case window.tabsIsNil", ur_yes(window.tabs == nil))];
    [lines addObject:ur_line(@"case window.shouldBeFocused", ur_yes(window.shouldBeFocused))];
    [lines addObject:ur_line(@"case window.shouldBePrivate", ur_yes(window.shouldBePrivate))];

    WKWebExtensionMessagePort *port = configuration_made_by_a_program(WKWebExtensionMessagePort.class);
    [lines addObject:ur_line(@"case port.class", NSStringFromClass([port class]))];
    [lines addObject:ur_line(@"case port.isAnObject", ur_yes(port != nil))];
    [lines addObject:ur_line(@"case port.applicationIdentifier", port.applicationIdentifier)];
    [lines addObject:ur_line(@"case port.isDisconnected", ur_yes(port.isDisconnected))];
    [lines addObject:ur_line(@"case port.messageHandlerIsNil", ur_yes(port.messageHandler == nil))];
    [lines addObject:ur_line(@"case port.disconnectHandlerIsNil", ur_yes(port.disconnectHandler == nil))];
    [port setMessageHandler:^(id message, NSError *error) {}];
    [port setDisconnectHandler:^(NSError *error) {}];
    [lines addObject:ur_line(@"case port.messageHandlerIsSet", ur_yes(port.messageHandler != nil))];
    [lines addObject:ur_line(@"case port.disconnectHandlerIsSet", ur_yes(port.disconnectHandler != nil))];

    [lines addObject:ur_line(@"case constant.MessagePortErrorDomain", WKWebExtensionMessagePortErrorDomain)];
    [lines addObject:ur_line(@"case enum.WindowTypeNormal", @(WKWebExtensionWindowTypeNormal))];
    [lines addObject:ur_line(@"case enum.WindowTypePopup", @(WKWebExtensionWindowTypePopup))];
    [lines addObject:ur_line(@"case enum.WindowStateNormal", @(WKWebExtensionWindowStateNormal))];
    [lines addObject:ur_line(@"case enum.WindowStateMinimized", @(WKWebExtensionWindowStateMinimized))];
    [lines addObject:ur_line(@"case enum.WindowStateMaximized", @(WKWebExtensionWindowStateMaximized))];
    [lines addObject:ur_line(@"case enum.WindowStateFullscreen", @(WKWebExtensionWindowStateFullscreen))];
    return lines;
}
