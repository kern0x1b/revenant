#import "RevenantWebKit.h"
#import <objc/runtime.h>

@implementation WKNavigation {
    NSURLRequest *_request;
}

- (NSURLRequest *)revenant_request
{
    return _request;
}

- (void)setRevenant_request:(NSURLRequest *)request
{
    _request = [request copy];
}

@end

@implementation WKFrameInfo {
    BOOL _mainFrame;
    NSURLRequest *_request;
}

+ (instancetype)revenant_frameWithMainFrame:(BOOL)mainFrame request:(NSURLRequest *)request
{
    WKFrameInfo *frame = [self alloc];
    frame->_mainFrame = mainFrame;
    frame->_request = [request copy];
    return frame;
}

- (BOOL)isMainFrame
{
    return _mainFrame;
}

- (NSURLRequest *)request
{
    return _request;
}

- (WKSecurityOrigin *)securityOrigin
{
    return [WKSecurityOrigin revenant_originWithURL:_request.URL];
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

@end

@implementation WKNavigationAction {
    NSURLRequest *_request;
    WKNavigationType _type;
    WKFrameInfo *_sourceFrame;
    WKFrameInfo *_targetFrame;
}

+ (instancetype)revenant_actionWithRequest:(NSURLRequest *)request type:(WKNavigationType)type mainFrame:(BOOL)mainFrame
{
    WKNavigationAction *action = [self alloc];
    action->_request = [request copy];
    action->_type = type;
    action->_sourceFrame = [WKFrameInfo revenant_frameWithMainFrame:mainFrame request:request];
    action->_targetFrame = [WKFrameInfo revenant_frameWithMainFrame:mainFrame request:request];
    return action;
}

- (NSURLRequest *)request
{
    return _request;
}

- (WKNavigationType)navigationType
{
    return _type;
}

- (WKFrameInfo *)sourceFrame
{
    return _sourceFrame;
}

- (WKFrameInfo *)targetFrame
{
    return _targetFrame;
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

@end

@implementation WKNavigationResponse {
    NSURLResponse *_response;
}

+ (instancetype)revenant_responseWithResponse:(NSURLResponse *)response
{
    WKNavigationResponse *navigationResponse = [self alloc];
    navigationResponse->_response = [response copy];
    return navigationResponse;
}

+ (WKNavigationResponsePolicy)revenant_policyAllowing:(BOOL)allowed
{
    return allowed ? WKNavigationResponsePolicyAllow : WKNavigationResponsePolicyCancel;
}

- (BOOL)isForMainFrame
{
    return YES;
}

- (NSURLResponse *)response
{
    return _response;
}

- (BOOL)canShowMIMEType
{
    NSString *mime = _response.MIMEType.lowercaseString;
    if (!mime.length)
        return NO;
    return [mime hasPrefix:@"text/"] || [mime hasPrefix:@"image/"] || [mime isEqualToString:@"application/xhtml+xml"]
        || [mime isEqualToString:@"application/pdf"];
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

@end
