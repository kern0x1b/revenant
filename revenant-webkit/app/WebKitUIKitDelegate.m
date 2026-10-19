#import "WebKitUIKitDelegate.h"

@implementation WebKitUIKitDelegate

@synthesize handler = _handler;

- (void)_webthread_webView:(WebView *)webView attachRootLayer:(id)rootLayer
{
    [_handler performSelectorOnMainThread:@selector(attachRootLayer:)
        withObject:rootLayer waitUntilDone:NO];
}

- (void)webView:(WebView *)webView contentsSizeChanged:(NSValue *)sizeValue forFrame:(WebFrame *)frame
{
    if (!sizeValue || ![_handler respondsToSelector:@selector(contentsSizeChanged:)])
        return;
    [_handler performSelectorOnMainThread:@selector(contentsSizeChanged:)
        withObject:sizeValue waitUntilDone:NO];
}

- (void)webView:(WebView *)webView didCommitLoadForFrame:(WebFrame *)frame { }
- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame { }
- (void)webView:(WebView *)sender didFailLoadWithError:(NSError *)error forFrame:(WebFrame *)frame { }
- (void)webView:(WebView *)sender didChangeLocationWithinPageForFrame:(WebFrame *)frame { }
- (void)webViewDidReceiveMobileDocType:(WebView *)webView { }
- (void)webView:(WebView *)aWebView didReceiveViewportArguments:(NSDictionary *)arguments { }
- (void)webView:(WebView *)aWebView needsScrollNotifications:(NSNumber *)aNumber forFrame:(WebFrame *)aFrame { }
- (void)webView:(WebView *)webView saveStateToHistoryItem:(WebHistoryItem *)item forFrame:(WebFrame *)frame { }
- (void)webView:(WebView *)webView restoreStateFromHistoryItem:(WebHistoryItem *)item forFrame:(WebFrame *)frame force:(BOOL)force { }
- (BOOL)webView:(WebView *)webView shouldScrollToPoint:(CGPoint)point forFrame:(WebFrame *)frame { return NO; }
- (void)webViewDidPreventDefaultForEvent:(WebView *)webView { }
- (void)webThreadWebViewDidLayout:(WebView *)webView byScrolling:(BOOL)byScrolling { }
- (void)webViewDidStartOverflowScroll:(WebView *)webView { }
- (void)webViewDidEndOverflowScroll:(WebView *)webView { }
- (void)webView:(WebView *)webView willCloseFrame:(WebFrame *)frame { }
- (void)webView:(WebView *)webView didFirstLayoutInFrame:(WebFrame *)frame { }
- (void)webView:(WebView *)webView didFirstVisuallyNonEmptyLayoutInFrame:(WebFrame *)frame { }
- (void)webView:(WebView *)webView elementDidFocusNode:(DOMNode *)node { }
- (void)webView:(WebView *)webView elementDidBlurNode:(DOMNode *)node { }
- (void)webViewDidRestoreFromPageCache:(WebView *)webView { }
- (void)webView:(WebView *)webView willShowFullScreenForPlugInView:(id)plugInView { }
- (void)webView:(WebView *)webView didHideFullScreenForPlugInView:(id)plugInView { }
- (void)webView:(WebView *)aWebView didReceiveMessage:(NSDictionary *)aMessage { }
- (void)addInputString:(NSString *)str withFlags:(NSUInteger)flags { }
- (BOOL)handleKeyTextCommandForCurrentEvent { return NO; }
- (BOOL)handleKeyAppCommandForCurrentEvent { return NO; }
- (void)deleteFromInput { }
- (void)deleteFromInputWithFlags:(NSUInteger)flags { }
- (void)webViewDidCommitCompositingLayerChanges:(WebView*)webView { }
- (void)webView:(WebView*)webView didCreateOrUpdateScrollingLayer:(id)layer withContentsLayer:(id)contentsLayer scrollSize:(NSValue*)sizeValue forNode:(DOMNode *)node allowHorizontalScrollbar:(BOOL)allowHorizontalScrollbar allowVerticalScrollbar:(BOOL)allowVerticalScrollbar { }
- (void)webView:(WebView*)webView willRemoveScrollingLayer:(id)layer withContentsLayer:(id)contentsLayer forNode:(DOMNode *)node { }
- (void)revealedSelectionByScrollingWebFrame:(WebFrame *)webFrame { }
- (NSArray *)checkSpellingOfString:(NSString *)stringToCheck { return nil; }
- (void)webView:(WebView *)webView willAddPlugInView:(id)plugInView { }
- (void)webViewDidDrawTiles:(WebView *)sender { }
- (void)writeDataToPasteboard:(NSDictionary*)representations { }
- (NSArray*)readDataFromPasteboard:(NSString*)type withIndex:(NSInteger)index { return nil; }
- (NSInteger)getPasteboardItemsCount { return 0; }
- (NSArray*)supportedPasteboardTypesForCurrentSelection { return nil; }
- (BOOL)hasRichlyEditableSelection { return NO; }
- (BOOL)performsTwoStepPaste:(DOMDocumentFragment*)fragment { return NO; }
- (BOOL)performTwoStepDrop:(DOMDocumentFragment *)fragment atDestination:(DOMRange *)destination isMove:(BOOL)isMove { return NO; }
- (NSInteger)getPasteboardChangeCount { return 0; }
- (CGPoint)interactionLocation { return CGPointZero; }
- (void)showPlaybackTargetPicker:(BOOL)hasVideo fromRect:(CGRect)elementRect { }
- (BOOL)shouldRevealCurrentSelectionAfterInsertion { return NO; }
- (BOOL)shouldSuppressPasswordEcho { return NO; }
- (int)deviceOrientation { return 0; }
- (void)webView:(WebView *)webView addMessageToConsole:(NSDictionary *)message withSource:(NSString *)source
{
    if ([_handler respondsToSelector:@selector(webView:addMessageToConsole:withSource:)])
        [(id)_handler webView:webView addMessageToConsole:message withSource:source];
}

@end
