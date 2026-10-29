#import <CoreGraphics/CoreGraphics.h>
#import "RevenantUIKitDelegate.h"

@implementation RevenantUIKitDelegate

@synthesize handler = _handler;

- (void)_webthread_webView:(id)webView attachRootLayer:(id)rootLayer
{
    id<RevenantRootLayerHandler> handler = _handler;
    dispatch_async(dispatch_get_main_queue(), ^{
        [handler attachRootLayer:rootLayer];
    });
}

- (void)webView:(id)webView contentsSizeChanged:(NSValue *)sizeValue forFrame:(id)frame
{
    id<RevenantRootLayerHandler> handler = _handler;
    if (!sizeValue || ![handler respondsToSelector:@selector(contentsSizeChanged:)])
        return;
    dispatch_async(dispatch_get_main_queue(), ^{
        [handler contentsSizeChanged:sizeValue];
    });
}

- (void)webView:(id)webView didCommitLoadForFrame:(id)frame { }
- (void)webView:(id)sender didFinishLoadForFrame:(id)frame { }
- (void)webView:(id)sender didFailLoadWithError:(NSError *)error forFrame:(id)frame { }
- (void)webView:(id)sender didChangeLocationWithinPageForFrame:(id)frame { }
- (void)webViewDidReceiveMobileDocType:(id)webView { }
- (void)webView:(id)aWebView didReceiveViewportArguments:(NSDictionary *)arguments { }
- (void)webView:(id)aWebView needsScrollNotifications:(NSNumber *)aNumber forFrame:(id)aFrame { }
- (void)webView:(id)webView saveStateToHistoryItem:(id)item forFrame:(id)frame { }
- (void)webView:(id)webView restoreStateFromHistoryItem:(id)item forFrame:(id)frame force:(BOOL)force { }
- (BOOL)webView:(id)webView shouldScrollToPoint:(CGPoint)point forFrame:(id)frame { return NO; }
- (void)webViewDidPreventDefaultForEvent:(id)webView { }
- (void)webThreadWebViewDidLayout:(id)webView byScrolling:(BOOL)byScrolling { }
- (void)webViewDidStartOverflowScroll:(id)webView { }
- (void)webViewDidEndOverflowScroll:(id)webView { }
- (void)webView:(id)webView willCloseFrame:(id)frame { }
- (void)webView:(id)webView didFirstLayoutInFrame:(id)frame { }
- (void)webView:(id)webView didFirstVisuallyNonEmptyLayoutInFrame:(id)frame { }
- (void)webView:(id)webView elementDidFocusNode:(id)node { }
- (void)webView:(id)webView elementDidBlurNode:(id)node { }
- (void)webViewDidRestoreFromPageCache:(id)webView { }
- (void)webView:(id)webView willShowFullScreenForPlugInView:(id)plugInView { }
- (void)webView:(id)webView didHideFullScreenForPlugInView:(id)plugInView { }
- (void)webView:(id)aWebView didReceiveMessage:(NSDictionary *)aMessage { }
- (void)addInputString:(NSString *)str withFlags:(NSUInteger)flags { }
- (BOOL)handleKeyTextCommandForCurrentEvent { return NO; }
- (BOOL)handleKeyAppCommandForCurrentEvent { return NO; }
- (void)deleteFromInput { }
- (void)deleteFromInputWithFlags:(NSUInteger)flags { }
- (void)webViewDidCommitCompositingLayerChanges:(id)webView { }
- (void)webView:(id)webView didCreateOrUpdateScrollingLayer:(id)layer withContentsLayer:(id)contentsLayer scrollSize:(NSValue *)sizeValue forNode:(id)node allowHorizontalScrollbar:(BOOL)allowHorizontalScrollbar allowVerticalScrollbar:(BOOL)allowVerticalScrollbar { }
- (void)webView:(id)webView willRemoveScrollingLayer:(id)layer withContentsLayer:(id)contentsLayer forNode:(id)node { }
- (void)revealedSelectionByScrollingWebFrame:(id)webFrame { }
- (NSArray *)checkSpellingOfString:(NSString *)stringToCheck { return nil; }
- (void)webView:(id)webView willAddPlugInView:(id)plugInView { }
- (void)webViewDidDrawTiles:(id)sender { }
- (void)writeDataToPasteboard:(NSDictionary *)representations { }
- (NSArray *)readDataFromPasteboard:(NSString *)type withIndex:(NSInteger)index { return nil; }
- (NSInteger)getPasteboardItemsCount { return 0; }
- (NSArray *)supportedPasteboardTypesForCurrentSelection { return nil; }
- (BOOL)hasRichlyEditableSelection { return NO; }
- (BOOL)performsTwoStepPaste:(id)fragment { return NO; }
- (BOOL)performTwoStepDrop:(id)fragment atDestination:(id)destination isMove:(BOOL)isMove { return NO; }
- (NSInteger)getPasteboardChangeCount { return 0; }
- (CGPoint)interactionLocation { return CGPointZero; }
- (void)showPlaybackTargetPicker:(BOOL)hasVideo fromRect:(CGRect)elementRect { }
- (BOOL)shouldRevealCurrentSelectionAfterInsertion { return NO; }
- (BOOL)shouldSuppressPasswordEcho { return NO; }
- (int)deviceOrientation { return 0; }
- (void)webView:(id)webView addMessageToConsole:(NSDictionary *)message withSource:(NSString *)source { }

@end
