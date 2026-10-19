/* The three value holders the web-extension family hands an application -- a tab's configuration, a
 * window's configuration and a message port -- asked of the SYSTEM's WebKit and of the PORT, from one
 * file, so the two cannot be asked different questions.
 *
 * The questions are asked of an object a PROGRAM made, and that is the only object either side can
 * make: nothing in the 26.2 SDK returns any of the three, and both headers mark +new and -init
 * NS_UNAVAILABLE. So the file asks for -init through the runtime, the way a program that ignores the
 * annotation would, and every answer below is the release's answer for that object.
 *
 * Compiled TWICE by run.sh: once plain, with no port code in the process, where the names below are
 * Apple's; and once with renames.sh's -D flags, where the very same names are the port's.
 */
#import "../uikit2/uirest.h"
/* The SDK's own WebKit, and NOT the port's headers: in the system build these are Apple's declarations,
 * and in the port build renames.sh's -D flags make the same declarations name the port's classes. */
#import <WebKit/WebKit.h>

/* -init is NS_UNAVAILABLE, so it is asked for through the runtime: an invocation is the only way to send
 * a selector the compiler refuses, and it is how the measurements in facts/WebKit/WebExtensionConfiguration.md
 * were taken too. */
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
    /* the invocation hands back the returned object as a void *, which under ARC needs the bridge the
     * compiler asks for; the object is autoreleased and this function returns it straight away */
    void *made = NULL;
    [invocation getReturnValue:&made];
    return (__bridge id)made;
}

static NSArray *webextension_configuration_scenario(void)
{
    NSMutableArray *lines = [NSMutableArray array];

    /* the two configurations, and the port each of them is asked for */
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
    /* the frame as its four numbers: the header promises NaN for a component that was not specified, and
     * whether it answers that or zeros is the question, so the numbers are what is compared */
    [lines addObject:ur_line(@"case window.frame", [NSString stringWithFormat:@"%g %g %g %g",
                                                      window.frame.origin.x, window.frame.origin.y,
                                                      window.frame.size.width, window.frame.size.height])];
    [lines addObject:ur_line(@"case window.tabURLsIsNil", ur_yes(window.tabURLs == nil))];
    [lines addObject:ur_line(@"case window.tabURLs.count", @(window.tabURLs.count))];
    [lines addObject:ur_line(@"case window.tabsIsNil", ur_yes(window.tabs == nil))];
    [lines addObject:ur_line(@"case window.shouldBeFocused", ur_yes(window.shouldBeFocused))];
    [lines addObject:ur_line(@"case window.shouldBePrivate", ur_yes(window.shouldBePrivate))];

    /* the message port, and the two handlers a caller may set on it */
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

    /* the error domain, whose value a caller reads when one of the port's errors arrives */
    [lines addObject:ur_line(@"case constant.MessagePortErrorDomain", WKWebExtensionMessagePortErrorDomain)];
    /* and the two enums a window's configuration is read through, asked by name so a wrong number in
     * the port's own header is caught here rather than by a caller */
    [lines addObject:ur_line(@"case enum.WindowTypeNormal", @(WKWebExtensionWindowTypeNormal))];
    [lines addObject:ur_line(@"case enum.WindowTypePopup", @(WKWebExtensionWindowTypePopup))];
    [lines addObject:ur_line(@"case enum.WindowStateNormal", @(WKWebExtensionWindowStateNormal))];
    [lines addObject:ur_line(@"case enum.WindowStateMinimized", @(WKWebExtensionWindowStateMinimized))];
    [lines addObject:ur_line(@"case enum.WindowStateMaximized", @(WKWebExtensionWindowStateMaximized))];
    [lines addObject:ur_line(@"case enum.WindowStateFullscreen", @(WKWebExtensionWindowStateFullscreen))];
    return lines;
}