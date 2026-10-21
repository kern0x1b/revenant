#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

static const char RevenantPaginationKey;

@interface RevenantPagination : NSObject <UIWebViewDelegate> {
@public
    UIWebPaginationMode mode;
    UIWebPaginationBreakingMode breaking;
    CGFloat length;
    CGFloat gap;
    __weak id<UIWebViewDelegate> appDelegate;
    __weak UIWebView *web;
    BOOL installed;
}
@end

static void (*revenant_native_set_web_delegate)(id, SEL, id);

static RevenantPagination *revenant_pagination(UIWebView *web)
{
    RevenantPagination *state = objc_getAssociatedObject(web, &RevenantPaginationKey);
    if (!state) {
        state = [[RevenantPagination alloc] init];
        state->web = web;
        objc_setAssociatedObject(web, &RevenantPaginationKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return state;
}

static void revenant_apply_pagination(UIWebView *web)
{
    RevenantPagination *state = revenant_pagination(web);
    NSString *script;
    if (state->mode == UIWebPaginationModeUnpaginated) {
        script = @"(function(){var b=document.body;if(!b)return;var t=b.style;t.webkitColumnWidth='';t.webkitColumnGap='';t.webkitColumnFill='';t.height='';document.documentElement.style.direction='';})()";
    } else {
        CGFloat width = state->length > 0 ? state->length : web.bounds.size.width;
        script = [NSString stringWithFormat:@"(function(){var b=document.body;if(!b)return;var t=b.style;t.webkitColumnWidth='%gpx';t.webkitColumnGap='%gpx';t.webkitColumnFill='auto';t.height=window.innerHeight+'px';document.documentElement.style.direction='%@';})()",
                  width, state->gap, state->mode == UIWebPaginationModeRightToLeft ? @"rtl" : @"ltr"];
    }
    [web stringByEvaluatingJavaScriptFromString:script];
}

static void revenant_install_pagination(UIWebView *web)
{
    RevenantPagination *state = revenant_pagination(web);
    if (state->installed || !revenant_native_set_web_delegate)
        return;
    state->installed = YES;
    revenant_native_set_web_delegate(web, @selector(setDelegate:), state);
}

@implementation RevenantPagination

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    if ([appDelegate respondsToSelector:_cmd])
        [appDelegate webViewDidFinishLoad:webView];
    revenant_apply_pagination(webView);
}

- (BOOL)respondsToSelector:(SEL)selector
{
    return [super respondsToSelector:selector] || [appDelegate respondsToSelector:selector];
}

- (id)forwardingTargetForSelector:(SEL)selector
{
    return [appDelegate respondsToSelector:selector] ? appDelegate : [super forwardingTargetForSelector:selector];
}

@end

@interface RevenantWebPagination7 : NSObject
@end

@implementation RevenantWebPagination7

+ (void)load
{
    if ([UIWebView instancesRespondToSelector:@selector(paginationMode)])
        return;
    Method set = class_getInstanceMethod([UIWebView class], @selector(setDelegate:));
    Method get = class_getInstanceMethod([UIWebView class], @selector(delegate));
    if (!set || !get)
        return;
    revenant_native_set_web_delegate = (void (*)(id, SEL, id))method_getImplementation(set);
    method_setImplementation(set, imp_implementationWithBlock(^(UIWebView *web, id<UIWebViewDelegate> delegate) {
        RevenantPagination *state = objc_getAssociatedObject(web, &RevenantPaginationKey);
        if (!state || !state->installed) {
            revenant_native_set_web_delegate(web, @selector(setDelegate:), delegate);
            return;
        }
        state->appDelegate = delegate;
    }));
    IMP original = method_getImplementation(get);
    method_setImplementation(get, imp_implementationWithBlock(^id(UIWebView *web) {
        RevenantPagination *state = objc_getAssociatedObject(web, &RevenantPaginationKey);
        if (state && state->installed)
            return state->appDelegate;
        return ((id (*)(id, SEL))original)(web, @selector(delegate));
    }));
}

@end

@implementation UIWebView (RevenantPagination7)

- (UIWebPaginationMode)paginationMode
{
    return revenant_pagination(self)->mode;
}

- (void)setPaginationMode:(UIWebPaginationMode)paginationMode
{
    if (paginationMode == UIWebPaginationModeTopToBottom || paginationMode == UIWebPaginationModeBottomToTop)
        [NSException raise:NSInternalInconsistencyException format:@"-[UIWebView setPaginationMode:] does not support the vertical pagination modes: the iOS 6 web view pages by CSS columns, which run horizontally"];
    RevenantPagination *state = revenant_pagination(self);
    if (!state->installed) {
        state->appDelegate = self.delegate;
        revenant_install_pagination(self);
    }
    state->mode = paginationMode;
    revenant_apply_pagination(self);
}

- (UIWebPaginationBreakingMode)paginationBreakingMode
{
    return revenant_pagination(self)->breaking;
}

- (void)setPaginationBreakingMode:(UIWebPaginationBreakingMode)paginationBreakingMode
{
    revenant_pagination(self)->breaking = paginationBreakingMode;
}

- (CGFloat)pageLength
{
    return revenant_pagination(self)->length;
}

- (void)setPageLength:(CGFloat)pageLength
{
    revenant_pagination(self)->length = pageLength;
    revenant_apply_pagination(self);
}

- (CGFloat)gapBetweenPages
{
    return revenant_pagination(self)->gap;
}

- (void)setGapBetweenPages:(CGFloat)gapBetweenPages
{
    revenant_pagination(self)->gap = gapBetweenPages;
    revenant_apply_pagination(self);
}

- (NSUInteger)pageCount
{
    RevenantPagination *state = revenant_pagination(self);
    if (state->mode == UIWebPaginationModeUnpaginated)
        return 1;
    CGFloat width = state->length > 0 ? state->length : self.bounds.size.width;
    NSString *script = [NSString stringWithFormat:@"Math.max(1,Math.ceil((document.documentElement.scrollWidth+%g)/(%g+%g)))", state->gap, width, state->gap];
    return (NSUInteger)MAX([[self stringByEvaluatingJavaScriptFromString:script] integerValue], 1);
}

@end
